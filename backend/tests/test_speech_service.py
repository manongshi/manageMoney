from __future__ import annotations

import json

from app.services import speech_service


def test_xfyun_signa_matches_documented_hmac_sha1_formula():
    signa = speech_service._build_xfyun_signa(
        app_id="test-app",
        secret_key="test-secret",
        ts="1700000000",
    )

    assert signa == "8wjxrxZbXf4XSSSzU0OTCfNHnFw="


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


def test_transcribe_audio_file_uploads_to_xfyun_and_polls_result(monkeypatch, tmp_path):
    audio_path = tmp_path / "voice.m4a"
    audio_path.write_bytes(b"fake audio")
    calls: list[dict] = []

    monkeypatch.setattr(speech_service.settings, "speech_provider", "xfyun")
    monkeypatch.setattr(speech_service.settings, "xfyun_app_id", "test-app")
    monkeypatch.setattr(speech_service.settings, "xfyun_secret_key", "test-secret")
    monkeypatch.setattr(speech_service.settings, "xfyun_poll_interval_seconds", 0)

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

        def post(self, url, params=None, headers=None, content=None):
            calls.append(
                {
                    "url": url,
                    "params": dict(params or {}),
                    "headers": dict(headers or {}),
                    "content": content,
                }
            )
            if url.endswith("/upload"):
                return FakeResponse(
                    {
                        "code": "000000",
                        "content": {"orderId": "order-1"},
                    }
                )
            return FakeResponse(
                {
                    "code": "000000",
                    "content": {
                        "orderInfo": {"status": 4},
                        "orderResult": json.dumps(
                            {
                                "lattice": [
                                    {
                                        "json_1best": {
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
                                        }
                                    }
                                ]
                            },
                            ensure_ascii=False,
                        ),
                    },
                }
            )

    monkeypatch.setattr(speech_service.httpx, "Client", FakeClient)
    monkeypatch.setattr(speech_service, "time", type("NoSleep", (), {"time": lambda: 1700000000, "sleep": lambda seconds: None}))

    transcript = speech_service.transcribe_audio_file(audio_path, "audio/mp4", "voice.m4a")

    assert transcript == "打车30元"
    assert [call["url"].rsplit("/", 1)[-1] for call in calls] == ["upload", "getResult"]
    upload = calls[0]
    assert upload["headers"]["Content-Type"] == "application/octet-stream"
    assert upload["content"] == b"fake audio"
    assert upload["params"]["appId"] == "test-app"
    assert upload["params"]["fileName"] == "voice.m4a"
    assert upload["params"]["fileSize"] == str(len(b"fake audio"))
    assert upload["params"]["signa"] == "8wjxrxZbXf4XSSSzU0OTCfNHnFw="
    result_query = calls[1]
    assert result_query["params"]["orderId"] == "order-1"
