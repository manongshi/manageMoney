from __future__ import annotations

import os
import threading
import time

CUSTOM_EPOCH_MS = 1_704_067_200_000  # 2024-01-01T00:00:00Z
WORKER_ID_BITS = 10
SEQUENCE_BITS = 12
MAX_WORKER_ID = (1 << WORKER_ID_BITS) - 1
MAX_SEQUENCE = (1 << SEQUENCE_BITS) - 1


class SnowflakeGenerator:
    def __init__(self, worker_id: int, epoch_ms: int = CUSTOM_EPOCH_MS):
        if worker_id < 0 or worker_id > MAX_WORKER_ID:
            raise ValueError(f"worker_id must be between 0 and {MAX_WORKER_ID}")
        self.worker_id = worker_id
        self.epoch_ms = epoch_ms
        self._lock = threading.Lock()
        self._last_timestamp_ms = -1
        self._sequence = 0

    def next_id(self) -> int:
        with self._lock:
            timestamp_ms = self._current_timestamp_ms()
            if timestamp_ms < self._last_timestamp_ms:
                raise RuntimeError("Clock moved backwards while generating snowflake id")

            if timestamp_ms == self._last_timestamp_ms:
                self._sequence = (self._sequence + 1) & MAX_SEQUENCE
                if self._sequence == 0:
                    timestamp_ms = self._wait_next_millisecond(self._last_timestamp_ms)
            else:
                self._sequence = 0

            self._last_timestamp_ms = timestamp_ms
            timestamp_part = timestamp_ms - self.epoch_ms
            if timestamp_part < 0:
                raise RuntimeError("Current timestamp is before the snowflake epoch")
            return (timestamp_part << (WORKER_ID_BITS + SEQUENCE_BITS)) | (self.worker_id << SEQUENCE_BITS) | self._sequence

    @staticmethod
    def _current_timestamp_ms() -> int:
        return time.time_ns() // 1_000_000

    def _wait_next_millisecond(self, last_timestamp_ms: int) -> int:
        timestamp_ms = self._current_timestamp_ms()
        while timestamp_ms <= last_timestamp_ms:
            timestamp_ms = self._current_timestamp_ms()
        return timestamp_ms


def _worker_id_from_env() -> int:
    return int(os.getenv("SNOWFLAKE_WORKER_ID", "1"))


_generator = SnowflakeGenerator(worker_id=_worker_id_from_env())


def generate_snowflake_id() -> int:
    return _generator.next_id()
