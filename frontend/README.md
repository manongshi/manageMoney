# AI智能记账 Flutter 前端

这是本项目的 Flutter 前端，连接根目录 `backend/` FastAPI 服务。

## 本地运行

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Android 模拟器访问宿主机本地后端时使用：

```powershell
flutter run -d emulator --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## 功能

- 登录、注册和 JWT 会话保存。
- 首页收支概览、预算使用率、最近账单。
- 文本智能入账，对接 `/ai/record`。
- 账单列表、筛选、新增、编辑、删除。
- 月度统计、分类支出、趋势图。
- 月预算查看和保存。
