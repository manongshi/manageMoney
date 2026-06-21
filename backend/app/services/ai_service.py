from __future__ import annotations

import re

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
    amount = _extract_amount(clean)
    bill_type = _detect_type(clean)
    category = _detect_category(clean, bill_type)
    remark = _extract_remark(clean, category)
    confidence = 0.86 if amount > 0 else 0.45
    return AIParseResult(
        amount=amount,
        category=category,
        bill_type=bill_type,
        remark=remark,
        confidence=confidence,
    )


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
