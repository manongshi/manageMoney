# AI智能记账项目运行说明

本项目按 `readme.md` 生成，当前版本去掉了数据导出功能，其余核心闭环已实现。

## 后端

目录：`backend/`

默认使用 SQLite，无需先安装 MySQL 或 Redis。

```powershell
cd backend
python -m pip install -r requirements.txt
copy .env.example .env
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

后端启动后可访问：

- `GET http://127.0.0.1:8000/health`
- `POST http://127.0.0.1:8000/auth/register`
- `POST http://127.0.0.1:8000/auth/login`

`.env` 中的 `DATABASE_URL` 可以切换到 MySQL，例如：

```env
DATABASE_URL=mysql+pymysql://user:password@127.0.0.1:3306/ai_account_book
```

如果切换 MySQL，需要额外安装对应驱动，例如 `pymysql`。

## Flutter 前端

目录：`frontend/`

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

前端默认请求 `http://127.0.0.1:8000`。如需改后端地址，运行时传入：

```powershell
flutter run --dart-define=API_BASE_URL=http://后端地址:8000
```

Android 模拟器访问宿主机本地后端时，地址通常要改为：

```powershell
flutter run -d emulator --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

本次已将原 UniApp 前端替换为 Flutter 前端，保留登录/注册、首页概览、文本智能入账、账单新增编辑删除、统计、预算和个人页。真实录音识别未迁移，当前 Flutter 端使用文本智能入账保证前后端闭环稳定。

## 已实现功能

- 注册、登录、JWT 鉴权、用户信息。
- 默认分类、分类列表、新增、修改、删除。
- 账单新增、编辑、删除、分页列表、关键词/类型/分类筛选。
- 首页 Dashboard：今日收支、本月收支、结余、连续记账、最近账单、预算使用率。
- 日统计、月统计、分类统计、趋势统计。
- 月预算保存、预算使用率、超预算提醒。
- AI 文本记账解析，本地规则兜底，无需 API Key。

## 本版未包含

- 数据导出。
- 真实录音和本地语音识别。
- Redis 缓存落地。
- OpenAI/DeepSeek 真实网络调用。

## 允许的轻量验证

```powershell
python -m pytest backend/tests/test_core_flow.py -q
python -m compileall backend/app backend/tests -q
cd frontend
flutter test test/app_model_test.dart
flutter analyze
```

未按你的要求运行 Maven、`npm run build` 或其他打包命令。
