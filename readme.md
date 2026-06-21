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

项目通过脚手架创建：

```bash
fastapi startproject ai_account_book
```

目录结构：

```text
backend
│
├── app
│   ├── api
│   │   ├── v1
│   │   │     ├── auth.py
│   │   │     ├── user.py
│   │   │     ├── bill.py
│   │   │     ├── category.py
│   │   │     ├── statistics.py
│   │   │     ├── budget.py
│   │   │     └── ai.py
│   │
│   ├── core
│   │     ├── config.py
│   │     ├── security.py
│   │     └── exceptions.py
│   │
│   ├── models
│   │     ├── user.py
│   │     ├── bill.py
│   │     ├── category.py
│   │     └── budget.py
│   │
│   ├── schemas
│   │     ├── user.py
│   │     ├── bill.py
│   │     └── statistics.py
│   │
│   ├── services
│   │     ├── ai_service.py
│   │     ├── speech_service.py
│   │     └── statistics_service.py
│   │
│   ├── utils
│   ├── middleware
│   └── main.py
│
├── alembic
└── requirements.txt
```

------

# 前端

技术：

- Uniapp
- Vue3
- Pinia
- uview-plus
- Echarts

通过脚手架创建：

```bash
npx degit dcloudio/uni-preset-vue#vite my-app
```

目录：

```text
frontend

├── pages
│     ├── index
│     ├── bill
│     ├── statistics
│     ├── budget
│     ├── profile
│     └── login
│
├── components
│     ├── bill-card
│     ├── category-tag
│     ├── pie-chart
│     └── line-chart
│
├── store
│     ├── user.js
│     └── bill.js
│
├── api
├── utils
└── static
```

支持：

- H5
- 微信小程序
- Android
- iOS

------

# 二、功能模块

## 1 用户模块

### 注册

手机号+密码

### 登录

JWT登录

返回：

```json
{
  "token": ""
}
```

### 用户信息

头像

昵称

性别

创建时间

### 修改密码

### 退出登录

------

## 2 分类模块

默认分类：

### 支出

餐饮

交通

购物

娱乐

生活

住房

医疗

学习

旅游

宠物

其他

### 收入

工资

奖金

兼职

红包

理财

其他

支持：

新增分类

修改分类

删除分类

排序

颜色设置

图标设置

------

## 3 手动记账

输入：

```json
{
    "amount":20,
    "category_id":1,
    "remark":"午饭",
    "bill_type":"expense"
}
```

支持：

- 支出
- 收入

记录：

- 时间
- 分类
- 金额
- 备注

------

# 4 AI语音记账

流程：

用户录音

↓

语音转文字

↓

调用 AI

↓

返回结构化数据

↓

确认

↓

保存账单

## 示例

用户说：

```text
今天中午吃麻辣烫花了25块
```

AI返回：

```json
{
    "amount":25,
    "category":"餐饮",
    "bill_type":"expense",
    "remark":"麻辣烫"
}
```

------

用户：

```text
打车花了18元
```

返回：

```json
{
    "amount":18,
    "category":"交通",
    "bill_type":"expense",
    "remark":"打车"
}
```

------

用户：

```text
工资到账8000元
```

返回：

```json
{
    "amount":8000,
    "category":"工资",
    "bill_type":"income",
    "remark":"工资"
}
```

------

## AI Prompt

系统提示词：

```text
你是一个记账助手。

根据用户输入，提取账单信息。

返回 JSON。

字段：

amount
category
bill_type
remark

bill_type只有：

expense
income

category可选：

餐饮
交通
购物
娱乐
生活
住房
医疗
学习
旅游
工资
奖金
红包
理财
其他

不要解释。

只返回JSON。
```

------

# 5 账单列表

支持：

分页

搜索

日期筛选

分类筛选

收入支出筛选

排序

接口：

```http
GET /bill/list
```

返回：

```json
{
  "total":100,
  "records":[]
}
```

------

# 6 首页 Dashboard

显示：

今日支出

今日收入

本月支出

本月收入

结余

连续记账天数

最近账单

预算使用率

------

# 7 每日统计

统计：

```text
收入

支出

结余
```

接口：

```http
GET /statistics/day
```

返回：

```json
{
  "income":100,
  "expense":80,
  "balance":20
}
```

------

# 8 月统计

返回：

```json
{
    "month":"2026-06",
    "income":10000,
    "expense":3500,
    "balance":6500
}
```

------

# 9 分类统计

饼图

例如：

```json
[
  {
      "name":"餐饮",
      "value":300
  },
  {
      "name":"交通",
      "value":200
  }
]
```

------

# 10 趋势统计

最近7天

最近30天

最近12个月

折线图

------

# 11 AI消费分析

输入：

最近30天账单

AI输出：

```json
{
    "summary":"本月餐饮消费偏高",
    "advice":"建议控制外卖次数"
}
```

生成：

消费报告

消费习惯分析

节省建议

------

# 12 预算模块

设置：

```json
{
  "month_budget":3000
}
```

统计：

```text
已消费

剩余预算

预算百分比
```

超过预算时：

发送提醒

------

# 13 搜索模块

支持：

关键词搜索

金额范围搜索

日期搜索

分类搜索

------

# 14 数据导出

导出：

Excel

CSV

接口：

```http
GET /bill/export
```

------

# 三、数据库设计

## 用户表 user

```sql
CREATE TABLE user (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50),
    password VARCHAR(255),
    nickname VARCHAR(50),
    avatar VARCHAR(255),
    gender INT,
    create_time DATETIME
);
```

------

## 分类表 category

```sql
CREATE TABLE category (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT,
    name VARCHAR(50),
    type VARCHAR(20),
    icon VARCHAR(50),
    color VARCHAR(20)
);
```

------

## 账单表 bill

```sql
CREATE TABLE bill (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT,
    amount DECIMAL(10,2),
    category_id BIGINT,
    bill_type VARCHAR(20),
    remark VARCHAR(255),
    bill_time DATETIME,
    create_time DATETIME
);
```

------

## 月预算表 budget

```sql
CREATE TABLE budget (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT,
    month_budget DECIMAL(10,2),
    create_time DATETIME
);
```

------

# 四、REST API

认证：

```text
POST /auth/register

POST /auth/login
```

账单：

```text
POST /bill/add

PUT /bill/update/{id}

DELETE /bill/delete/{id}

GET /bill/list
```

分类：

```text
GET /category/list

POST /category/add
```

统计：

```text
GET /statistics/day

GET /statistics/month

GET /statistics/category

GET /statistics/trend
```

预算：

```text
POST /budget/save

GET /budget/info
```

AI：

```text
POST /ai/parse
```

------

# 五、页面

## 登录页

手机号登录

密码登录

验证码登录

------

## 首页

Dashboard

最近账单

今日收支

快捷记账

语音记账按钮

------

## 账单页

账单列表

新增账单

编辑

删除

搜索

------

## 统计页

饼图

折线图

柱状图

月统计

分类统计

趋势统计

------

## 预算页

预算进度条

剩余金额

预算提醒

------

## 我的

头像

昵称

设置

退出登录

------

# 六、缓存

Redis缓存：

首页统计

分类列表

最近账单

Token黑名单

------

# 七、日志

记录：

接口日志

异常日志

AI调用日志

登录日志

------

# 八、异常处理

统一返回：

```json
{
    "code":200,
    "msg":"success",
    "data":{}
}
```

失败：

```json
{
    "code":500,
    "msg":"error",
    "data":null
}
```

------

# 九、后续扩展

多人共享账本

情侣记账

家庭记账

微信登录

支付宝账单导入

OCR识别小票

定时提醒

消费排行榜

资产管理

信用卡管理

基金股票收益统计

AI理财建议

账单云同步

深色模式

桌面小组件

PWA

离线模式

多语言支持

