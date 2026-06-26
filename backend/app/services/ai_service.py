from __future__ import annotations

import json
import re

import httpx

from app.core.config import settings
from app.core.exceptions import ApiError
from app.schemas.ai import AIParseResult

INCOME_KEYWORDS = ["工资", "奖金", "兼职", "红包", "理财", "到账", "收入", "发了"]
EXPENSE_HINTS = ["花", "买", "吃", "喝", "打车", "地铁", "公交", "消费", "支出", "付"]

CATEGORY_KEYWORDS: dict[str, list[str]] = {
    "餐饮": ["餐饮", "吃", "饭", "早餐", "午饭", "晚饭", "午餐", "晚餐", "麻辣烫", "奶茶", "咖啡", "外卖"],
    "交通": ["交通", "打车", "出租", "地铁", "公交", "车费", "加油", "停车"],
    "购物": ["购物", "买", "衣服", "鞋", "超市", "淘宝", "京东"],
    "娱乐": ["娱乐", "电影", "游戏", "唱歌", "会员"],
    "生活": ["生活", "水电", "日用品", "话费", "物业"],
    "住房": ["住房", "房租", "房贷", "租房"],
    "医疗": ["医疗", "看病", "药", "医院"],
    "学习": ["学习", "课程", "书", "培训"],
    "旅游": ["旅游", "酒店", "机票", "火车票"],
    "宠物": ["宠物", "猫", "狗", "猫粮", "狗粮"],
    "工资": ["工资", "薪水", "薪资"],
    "奖金": ["奖金", "绩效"],
    "兼职": ["兼职", "外快"],
    "红包": ["红包"],
    "理财": ["理财", "利息", "分红", "收益"],
}

SPECIFIC_REMARKS = ["麻辣烫", "打车", "工资", "奖金", "红包", "奶茶", "咖啡", "房租", "话费"]
AMOUNT_RE = re.compile(r"(\d+(?:\.\d+)?)\s*(?:元|块钱|块)?")


def parse_bill_text(text: str) -> AIParseResult:
    clean = text.strip()
    if settings.ai_provider.lower() == "deepseek":
        if not settings.deepseek_api_key:
            raise ApiError("DeepSeek API Key 未配置，无法进行 AI 账单分析")
        return parse_bill_text_with_deepseek(
            clean,
            api_key=settings.deepseek_api_key,
            base_url=settings.deepseek_base_url,
            model=settings.deepseek_model,
        )

    return parse_bill_text_locally(clean)


def parse_bill_text_locally(text: str) -> AIParseResult:
    amount = _extract_amount(text)
    bill_type = _detect_type(text)
    category = _detect_category(text, bill_type)
    remark = _extract_remark(text, category)
    confidence = 0.86 if amount > 0 else 0.45
    return AIParseResult(
        amount=amount,
        category=category,
        bill_type=bill_type,
        remark=remark,
        confidence=confidence,
    )


def parse_bill_text_with_deepseek(
    text: str,
    *,
    api_key: str,
    base_url: str,
    model: str,
) -> AIParseResult:
    if not text.strip():
        raise ApiError("语音内容为空，无法分析账单")

    url = f"{base_url.rstrip('/')}/chat/completions"
    payload = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "你是记账助手。请只返回 JSON，不要解释。"
                    "字段：amount 数字金额；category 中文分类名；"
                    "bill_type 只能是 income 或 expense；remark 简短备注；"
                    "confidence 0 到 1。没有明确收入关键词时默认 expense。"
                ),
            },
            {"role": "user", "content": text},
        ],
        "temperature": 0,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    try:
        with httpx.Client(timeout=30) as client:
            response = client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            content = response.json()["choices"][0]["message"]["content"]
    except (httpx.HTTPError, KeyError, IndexError, TypeError) as exc:
        raise ApiError("DeepSeek 账单分析失败，请稍后重试") from exc

    try:
        data = json.loads(content)
    except json.JSONDecodeError as exc:
        raise ApiError("DeepSeek 返回格式无法解析") from exc

    bill_type = str(data.get("bill_type") or "expense").strip().lower()
    if bill_type not in {"income", "expense"}:
        bill_type = "expense"

    amount = read_float(data.get("amount"))
    category = str(data.get("category") or "其他").strip() or "其他"
    remark = str(data.get("remark") or category).strip() or category
    confidence = max(0.0, min(1.0, read_float(data.get("confidence"), default=0.8)))

    return AIParseResult(
        amount=amount,
        category=category,
        bill_type=bill_type,
        remark=remark,
        confidence=confidence,
    )


def read_float(value: object, *, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _extract_amount(text: str) -> float:
    match = AMOUNT_RE.search(text)
    if not match:
        return 0.0
    return float(match.group(1))


def _detect_type(text: str) -> str:
    has_income = any(keyword in text for keyword in INCOME_KEYWORDS)
    has_expense = any(keyword in text for keyword in EXPENSE_HINTS)
    if has_income and not has_expense:
        return "income"
    return "income" if text.startswith(("收", "赚")) else "expense"


def _detect_category(text: str, bill_type: str) -> str:
    candidates = ["工资", "奖金", "兼职", "红包", "理财"] if bill_type == "income" else [
        "餐饮",
        "交通",
        "购物",
        "娱乐",
        "生活",
        "住房",
        "医疗",
        "学习",
        "旅游",
        "宠物",
    ]
    for category in candidates:
        if any(keyword in text for keyword in CATEGORY_KEYWORDS.get(category, [])):
            return category
    return "其他"


def _extract_remark(text: str, category: str) -> str:
    for remark in SPECIFIC_REMARKS:
        if remark in text:
            return remark
    remark = AMOUNT_RE.sub("", text)
    for token in ["今天", "昨天", "中午", "晚上", "早上", "上午", "下午", "花了", "花", "用了", "消费", "到账", "收入"]:
        remark = remark.replace(token, "")
    remark = remark.strip(" ，。,.")
    return remark or category
