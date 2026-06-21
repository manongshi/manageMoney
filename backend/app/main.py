from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.exceptions import ApiError
from app.core.responses import error
from app.db import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    _ = app
    init_db()
    yield


app = FastAPI(title=settings.app_name, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.exception_handler(ApiError)
async def api_error_handler(request: Request, exc: ApiError):
    _ = request
    return JSONResponse(status_code=exc.status_code, content=error(exc.message, code=exc.code))


@app.exception_handler(HTTPException)
async def http_error_handler(request: Request, exc: HTTPException):
    _ = request
    return JSONResponse(status_code=exc.status_code, content=error(str(exc.detail), code=exc.status_code))


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    _ = request
    return JSONResponse(status_code=422, content=error("参数校验失败", code=422, data=exc.errors()))


app.include_router(api_router)
