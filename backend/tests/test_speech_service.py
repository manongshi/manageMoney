from __future__ import annotations

import json
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_ROOT))

from app.services import speech_service


def test_xfyun_llm_signature_uses_sorted_url_encoded_query_params():
    params = {
        "appId": "test-app",
        "accessKeyId": "test-key",
        "dateTime": "2025-09-08T22:58:29+0800",
        "signatureRandom": "moI5WkopgjL1EL5Y",
        "fileSize": "397144",
        "fileName": "voice 1+.mp3",
        "durationCheckDisable": "true",
        "language": "autodialect",
        "audioMode": "fileStream",
    }

    base_string = speech_service._build_xfyun_llm_base_string(params)
    signature = speech_service._build_xfyun_llm_signature("test-secret", params)

    assert (
        base_string
        == "accessKeyId=test-key&appId=test-app&audioMode=fileStream&"
        "dateTime=2025-09-08T22%3A58%3A29%2B0800&durationCheckDisable=true&"
        "fileName=voice+1%2B.mp3&fileSize=397144&language=autodialect&"
        "signatureRandom=moI5WkopgjL1EL5Y"
    )
    assert signature == "I7fEbZJnD3hSJMb36LH7rK9Qbrw="


def test_extract_xfyun_transcript_from_lattice_order_result():
    order_result = json.dumps(
        {
            "lattice": [
                {
                    "json_1best": {
                        "st": {
                            "rt": [
                                {
                                    "ws": [
                                        {"cw": [{"w": "今天"}]},
                                        {"cw": [{"w": "花了"}]},
                                        {"cw": [{"w": "25块"}]},
                                    ]
                                }
                            ]
                        }
                    }
                }
            ]
        },
        ensure_ascii=False,
    )

    assert speech_service._extract_xfyun_transcript(order_result) == "今天花了25块"


def test_transcribe_audio_file_uploads_to_xfyun_llm_and_polls_result(monkeypatch, tmp_path):
    audio_path = tmp_path / "voice.m4a"
    audio_path.write_bytes(b"fake audio")
    calls: list[dict] = []

    monkeypatch.setattr(speech_service.settings, "speech_provider", "xfyun")
    monkeypatch.setattr(speech_service.settings, "xfyun_app_id", "test-app")
    monkeypatch.setattr(speech_service.settings, "xfyun_api_key", "test-key")
    monkeypatch.setattr(speech_service.settings, "xfyun_api_secret", "test-secret")
    monkeypatch.setattr(speech_service.settings, "xfyun_base_url", "https://office-api-ist-dx.iflyaisol.com")
    monkeypatch.setattr(speech_service.settings, "xfyun_duration_check_disable", True)
    monkeypatch.setattr(speech_service.settings, "xfyun_language", "autodialect")
    monkeypatch.setattr(speech_service.settings, "xfyun_poll_interval_seconds", 0)
    monkeypatch.setattr(speech_service, "_xfyun_now", lambda: "2025-09-08T22:58:29+0800")
    monkeypatch.setattr(speech_service, "_xfyun_signature_random", lambda: "moI5WkopgjL1EL5Y")

    class FakeResponse:
        def __init__(self, payload):
            self.payload = payload

        def raise_for_status(self):
            return None

        def json(self):
            return self.payload

    class FakeClient:
        def __init__(self, timeout):
            self.timeout = timeout

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def post(self, url, params=None, headers=None, content=None, json=None):
            calls.append(
                {
                    "url": url,
                    "params": dict(params or {}),
                    "headers": dict(headers or {}),
                    "content": content,
                    "json": json,
                }
            )
            if url.endswith("/v2/upload"):
                return FakeResponse(
                    {
                        "code": "000000",
                        "content": {"orderId": "order-1", "taskEstimateTime": 1000},
                    }
                )
            return FakeResponse(
                {
                    "code": "000000",
                    "content": {
                        "orderInfo": {"status": 4, "failType": 0},
                        "orderResult": json_module.dumps(
                            {
                                "lattice": [
                                    {
                                        "json_1best": json_module.dumps(
                                            {
                                                "st": {
                                                    "rt": [
                                                        {
                                                            "ws": [
                                                                {"cw": [{"w": "打车"}]},
                                                                {"cw": [{"w": "30元"}]},
                                                            ]
                                                        }
                                                    ]
                                                }
                                            },
                                            ensure_ascii=False,
                                        )
                                    }
                                ]
                            },
                            ensure_ascii=False,
                        ),
                    },
                }
            )

    json_module = json
    monkeypatch.setattr(speech_service.httpx, "Client", FakeClient)

    transcript = speech_service.transcribe_audio_file(audio_path, "audio/mp4", "voice.m4a")

    assert transcript == "打车30元"
    assert [call["url"] for call in calls] == [
        "https://office-api-ist-dx.iflyaisol.com/v2/upload",
        "https://office-api-ist-dx.iflyaisol.com/v2/getResult",
    ]

    upload = calls[0]
    assert upload["headers"]["Content-Type"] == "application/octet-stream"
    assert upload["headers"]["signature"] == speech_service._build_xfyun_llm_signature(
        "test-secret",
        upload["params"],
    )
    assert upload["content"] == b"fake audio"
    assert "signature" not in upload["params"]
    assert upload["params"] == {
        "appId": "test-app",
        "accessKeyId": "test-key",
        "dateTime": "2025-09-08T22:58:29+0800",
        "signatureRandom": "moI5WkopgjL1EL5Y",
        "fileSize": str(len(b"fake audio")),
        "fileName": "voice.m4a",
        "durationCheckDisable": "true",
        "language": "autodialect",
        "audioMode": "fileStream",
    }

    result_query = calls[1]
    assert result_query["headers"]["Content-Type"] == "application/json"
    assert result_query["headers"]["signature"] == speech_service._build_xfyun_llm_signature(
        "test-secret",
        result_query["params"],
    )
    assert result_query["json"] == {}
    assert "appId" not in result_query["params"]
    assert result_query["params"] == {
        "accessKeyId": "test-key",
        "dateTime": "2025-09-08T22:58:29+0800",
        "signatureRandom": "moI5WkopgjL1EL5Y",
        "orderId": "order-1",
        "resultType": "transfer",
    }
