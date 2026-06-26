from __future__ import annotations

import base64
import hmac
import json
import secrets
import string
import time
from datetime import datetime
from hashlib import sha1
from pathlib import Path
from typing import Any
from urllib.parse import quote_plus

import httpx

from app.core.config import settings
from app.core.exceptions import ApiError

_XFYUN_SUCCESS_CODES = {"0", "000000"}
_XFYUN_RANDOM_ALPHABET = string.ascii_letters + string.digits


def transcribe_audio_file(
    audio_path: str | Path,
    content_type: str | None = None,
    filename: str | None = None,
) -> str:
    provider = settings.speech_provider.lower().strip()
    path = _valid_audio_path(audio_path)

    if provider == "xfyun":
        return _transcribe_audio_with_xfyun(path, filename)
    if provider == "openai":
        return _transcribe_audio_with_openai(path, content_type, filename)

    raise ApiError(f"不支持的语音识别服务：{settings.speech_provider}")


def _valid_audio_path(audio_path: str | Path) -> Path:
    path = Path(audio_path)
    if not path.exists() or path.stat().st_size == 0:
        raise ApiError("录音文件为空，无法识别")
    return path


def _build_xfyun_llm_base_string(params: dict[str, Any]) -> str:
    pieces: list[str] = []
    for key in sorted(params):
        if key == "signature":
            continue
        value = params[key]
        if value is None or str(value) == "":
            continue
        encoded_key = quote_plus(str(key), safe="")
        encoded_value = quote_plus(str(value), safe="")
        pieces.append(f"{encoded_key}={encoded_value}")
    return "&".join(pieces)


def _build_xfyun_llm_signature(api_secret: str, params: dict[str, Any]) -> str:
    base_string = _build_xfyun_llm_base_string(params)
    digest = hmac.new(api_secret.encode("utf-8"), base_string.encode("utf-8"), sha1).digest()
    return base64.b64encode(digest).decode("utf-8")


def _xfyun_now() -> str:
    return datetime.now().astimezone().strftime("%Y-%m-%dT%H:%M:%S%z")


def _xfyun_signature_random() -> str:
    return "".join(secrets.choice(_XFYUN_RANDOM_ALPHABET) for _ in range(16))


def _xfyun_credentials() -> tuple[str, str, str]:
    if not settings.xfyun_app_id or not settings.xfyun_api_key or not settings.xfyun_api_secret:
        raise ApiError("讯飞语音识别服务未配置，请先配置 XFYUN_APP_ID、XFYUN_API_KEY 和 XFYUN_API_SECRET")
    return settings.xfyun_app_id, settings.xfyun_api_key, settings.xfyun_api_secret


def _xfyun_signed_headers(api_secret: str, params: dict[str, Any], content_type: str) -> dict[str, str]:
    return {
        "Content-Type": content_type,
        "signature": _build_xfyun_llm_signature(api_secret, params),
    }


def _transcribe_audio_with_xfyun(audio_path: Path, filename: str | None = None) -> str:
    app_id, api_key, api_secret = _xfyun_credentials()
    base_url = settings.xfyun_base_url.rstrip("/")
    upload_url = f"{base_url}/v2/upload"
    result_url = f"{base_url}/v2/getResult"
    signature_random = _xfyun_signature_random()
    upload_params = _xfyun_upload_params(app_id, api_key, signature_random, audio_path, filename)

    try:
        with httpx.Client(timeout=120) as client:
            upload_response = client.post(
                upload_url,
                params=upload_params,
                headers=_xfyun_signed_headers(api_secret, upload_params, "application/octet-stream"),
                content=audio_path.read_bytes(),
            )
            upload_response.raise_for_status()
            upload_payload = upload_response.json()
            upload_content = _require_xfyun_success(upload_payload, "文件上传")
            order_id = upload_content.get("orderId")
            if not order_id:
                raise ApiError("讯飞语音识别上传失败：未返回任务编号")

            order_result = _poll_xfyun_result(client, result_url, api_key, api_secret, signature_random, str(order_id))
    except httpx.HTTPError as exc:
        raise ApiError("讯飞语音识别请求失败，请稍后重试") from exc
    except json.JSONDecodeError as exc:
        raise ApiError("讯飞语音识别返回格式错误") from exc

    transcript = _extract_xfyun_transcript(order_result)
    if not transcript:
        raise ApiError("没有识别到语音内容，请重新录制")
    return transcript


def _xfyun_upload_params(
    app_id: str,
    api_key: str,
    signature_random: str,
    audio_path: Path,
    filename: str | None,
) -> dict[str, str]:
    params = {
        "appId": app_id,
        "accessKeyId": api_key,
        "dateTime": _xfyun_now(),
        "signatureRandom": signature_random,
        "fileSize": str(audio_path.stat().st_size),
        "fileName": filename or audio_path.name,
        "durationCheckDisable": str(bool(settings.xfyun_duration_check_disable)).lower(),
        "language": settings.xfyun_language,
        "audioMode": "fileStream",
    }
    if not settings.xfyun_duration_check_disable:
        params["duration"] = str(settings.xfyun_audio_duration_ms)
    return params


def _poll_xfyun_result(
    client: httpx.Client,
    result_url: str,
    api_key: str,
    api_secret: str,
    signature_random: str,
    order_id: str,
) -> str:
    attempts = max(int(settings.xfyun_max_poll_attempts), 1)
    for index in range(attempts):
        params = {
            "accessKeyId": api_key,
            "dateTime": _xfyun_now(),
            "signatureRandom": signature_random,
            "orderId": order_id,
            "resultType": "transfer",
        }
        response = client.post(
            result_url,
            params=params,
            headers=_xfyun_signed_headers(api_secret, params, "application/json"),
            json={},
        )
        response.raise_for_status()
        payload = response.json()
        content = _require_xfyun_success(payload, "结果查询")
        order_info = content.get("orderInfo") or {}
        status = _status_code(order_info.get("status"))
        fail_type = _status_code(order_info.get("failType"))

        if status == 4 or content.get("orderResult"):
            order_result = content.get("orderResult")
            if not order_result:
                raise ApiError("讯飞语音识别完成但未返回结果")
            return str(order_result)

        if status == -1 or fail_type not in (0, None):
            raise ApiError(f"讯飞语音识别失败：{order_info.get('failType', '未知错误')}")

        if index < attempts - 1:
            time.sleep(max(float(settings.xfyun_poll_interval_seconds), 0))

    raise ApiError("讯飞语音识别超时，请稍后重试")


def _require_xfyun_success(payload: dict[str, Any], action: str) -> dict[str, Any]:
    code = str(payload.get("code", ""))
    if code not in _XFYUN_SUCCESS_CODES:
        message = payload.get("descInfo") or payload.get("message") or payload.get("desc") or "未知错误"
        raise ApiError(f"讯飞语音识别{action}失败：{message}")

    content = payload.get("content") or {}
    if not isinstance(content, dict):
        raise ApiError(f"讯飞语音识别{action}返回格式错误")
    return content


def _status_code(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _extract_xfyun_transcript(order_result: str | dict[str, Any]) -> str:
    parsed: Any = order_result
    if isinstance(order_result, str):
        text = order_result.strip()
        if not text:
            return ""
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            return text

    if not isinstance(parsed, dict):
        return ""

    for key in ("lattice", "lattice2"):
        transcript = _extract_lattice_text(parsed.get(key))
        if transcript:
            return transcript

    return _extract_direct_text(parsed)


def _extract_lattice_text(lattice: Any) -> str:
    if not isinstance(lattice, list):
        return ""

    pieces: list[str] = []
    for item in lattice:
        if not isinstance(item, dict):
            continue
        best = item.get("json_1best") or item.get("json_1best_cw")
        if isinstance(best, str):
            try:
                best = json.loads(best)
            except json.JSONDecodeError:
                continue
        if isinstance(best, dict):
            pieces.extend(_extract_st_words(best.get("st")))
    return "".join(pieces).strip()


def _extract_st_words(st: Any) -> list[str]:
    if not isinstance(st, dict):
        return []

    words: list[str] = []
    for rt in st.get("rt") or []:
        if not isinstance(rt, dict):
            continue
        for ws in rt.get("ws") or []:
            if not isinstance(ws, dict):
                continue
            candidates = ws.get("cw") or []
            if not candidates:
                continue
            candidate = candidates[0]
            if isinstance(candidate, dict):
                word = str(candidate.get("w") or "")
                if word:
                    words.append(word)
    return words


def _extract_direct_text(payload: dict[str, Any]) -> str:
    for key in ("text", "onebest", "result", "transcript"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def _transcribe_audio_with_openai(
    audio_path: Path,
    content_type: str | None = None,
    filename: str | None = None,
) -> str:
    if not settings.openai_api_key:
        raise ApiError("语音识别服务未配置，请先配置 OPENAI_API_KEY")

    url = f"{settings.openai_base_url.rstrip('/')}/audio/transcriptions"
    headers = {"Authorization": f"Bearer {settings.openai_api_key}"}
    data = {
        "model": settings.openai_audio_model,
        "language": "zh",
        "response_format": "text",
    }

    try:
        with audio_path.open("rb") as audio_file:
            files = {
                "file": (
                    filename or audio_path.name,
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
