# AI 智能记账 APP 项目文档

# 一、技术栈

## 后端

- Python 3.12
- FastAPI
- SQLAlchemy 2.x
- Pydantic
- JWT
- MySQL 8
- Alembic
- Redis（缓存）
- OpenAI API（或 DeepSeek）
- Faster-whisper（可选，本地语音识别）
- uvicorn

# 二、运行

## 后端

```python
pip install -r requirements.txt

python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```



## 前端

```
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```
