from __future__ import annotations

from pathlib import Path

import httpx

from app.core.config import settings
from app.core.exceptions import ApiError


def transcribe_audio_file(
    audio_path: str | Path,
    content_type: str | None = None,
    filename: str | None = None,
) -> str:
    if not settings.openai_api_key:
        raise ApiError("语音识别服务未配置，请先配置 OPENAI_API_KEY")

    path = Path(audio_path)
    if not path.exists() or path.stat().st_size == 0:
        raise ApiError("录音文件为空，无法识别")

    url = f"{settings.openai_base_url.rstrip('/')}/audio/transcriptions"
    headers = {"Authorization": f"Bearer {settings.openai_api_key}"}
    data = {
        "model": settings.openai_audio_model,
        "language": "zh",
        "response_format": "text",
    }

    try:
        with path.open("rb") as audio_file:
            files = {
                "file": (
                    filename or path.name,
                    audio_file,
                    content_type or "application/octet-stream",
                )
            }
            with httpx.Client(timeout=90) as client:
                response = client.post(url, headers=headers, data=data, files=files)
                response.raise_for_status()
    except httpx.HTTPError as exc:
        raise ApiError("语音识别失败，请稍后重试") from exc

    transcript = response.text.strip()
    if not transcript:
        raise ApiError("没有识别到语音内容，请重新录制")
    return transcript
