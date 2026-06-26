from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.core.exceptions import ApiError
from app.core.responses import success
from app.core.security import get_current_user
from app.db import get_db
from app.models.bill import Bill
from app.models.category import Category
from app.models.user import User
from app.schemas.ai import AIParseRequest, AIRecordResult
from app.schemas.bill import BillOut
from app.services.ai_service import parse_bill_text
from app.services.speech_service import transcribe_audio_file

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/parse")
def parse_bill(payload: AIParseRequest, current_user: User = Depends(get_current_user)):
    _ = current_user
    return success(parse_bill_text(payload.text).model_dump())


@router.post("/record")
def record_bill(
    payload: AIParseRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    parsed = parse_bill_text(payload.text)
    saved_bill = _save_parsed_bill(db, current_user, parsed)
    result = AIRecordResult(parsed=parsed, bill=BillOut.model_validate(saved_bill))
    return success(result.model_dump())


def _save_audio_upload(file: UploadFile, user_id: int) -> Path:
    suffix = Path(file.filename or "").suffix.lower() or ".m4a"
    if suffix not in {
        ".aac",
        ".amr",
        ".flac",
        ".m4a",
        ".mp3",
        ".mp4",
        ".mpeg",
        ".ogg",
        ".wav",
        ".webm",
    }:
        suffix = ".m4a"

    upload_dir = Path(settings.voice_upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    target = upload_dir / f"{user_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid4().hex}{suffix}"

    with target.open("wb") as output:
        while chunk := file.file.read(1024 * 1024):
            output.write(chunk)
    return target


@router.post("/record-audio")
def record_audio_bill(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    audio_path = _save_audio_upload(file, current_user.id)
    try:
        transcript = transcribe_audio_file(audio_path, file.content_type, file.filename)
        parsed = parse_bill_text(transcript)
        saved_bill = _save_parsed_bill(db, current_user, parsed)
        result = AIRecordResult(parsed=parsed, bill=BillOut.model_validate(saved_bill))
        data = result.model_dump()
        data["transcript"] = transcript
        return success(data)
    finally:
        audio_path.unlink(missing_ok=True)


def _save_parsed_bill(db: Session, current_user: User, parsed):
    if parsed.amount <= 0:
        raise ApiError("未识别到有效金额")

    category = _match_category(db, current_user.id, parsed.category, parsed.bill_type)
    bill = Bill(
        user_id=current_user.id,
        amount=Decimal(str(parsed.amount)),
        category_id=category.id,
        bill_type=parsed.bill_type,
        remark=parsed.remark,
        bill_time=datetime.now(),
    )
    db.add(bill)
    db.commit()
    db.refresh(bill)
    saved_bill = db.scalar(
        select(Bill)
        .options(joinedload(Bill.category))
        .where(Bill.id == bill.id, Bill.user_id == current_user.id)
    )
    return saved_bill


def _match_category(db: Session, user_id: int, name: str, bill_type: str) -> Category:
    category = db.scalar(
        select(Category).where(
            Category.user_id == user_id,
            Category.type == bill_type,
            Category.name == name,
        )
    )
    if category:
        return category

    fallback = db.scalar(
        select(Category).where(
            Category.user_id == user_id,
            Category.type == bill_type,
            Category.name == "其他",
        )
    )
    if fallback:
        return fallback

    first_category = db.scalar(
        select(Category)
        .where(Category.user_id == user_id, Category.type == bill_type)
        .order_by(Category.sort_order.asc(), Category.id.asc())
    )
    if first_category is None:
        raise ApiError("请先创建分类")
    return first_category
