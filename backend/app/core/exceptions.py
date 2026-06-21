from __future__ import annotations


class ApiError(Exception):
    def __init__(self, message: str, status_code: int = 400, code: int | None = None):
        self.message = message
        self.status_code = status_code
        self.code = code or status_code
        super().__init__(message)
