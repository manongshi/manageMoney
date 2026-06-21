from __future__ import annotations

from typing import Any


def success(data: Any = None, msg: str = "success") -> dict[str, Any]:
    return {"code": 200, "msg": msg, "data": data if data is not None else {}}


def error(msg: str = "error", code: int = 500, data: Any = None) -> dict[str, Any]:
    return {"code": code, "msg": msg, "data": data}
