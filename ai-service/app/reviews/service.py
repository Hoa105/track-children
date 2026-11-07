"""Đánh giá tổng hợp: gom các nhận xét video đã xong của một bé (một hoặc nhiều hoạt
động trong khoảng thời gian ba mẹ chọn) → AI viết nhận xét về sự thay đổi theo thời
gian + chuỗi số đo cho biểu đồ.

Chỉ đọc văn bản (nhận xét + số đo), video gốc đã bị xóa nên không gửi hình. Gọi AI
đồng bộ trong request: một lượt chỉ có văn bản, thường xong trong vài giây.
"""

from uuid import UUID

from app.insights.repository import InsightStore
from app.llm.client import LLMError, TextGenerator, TransientLLMError
from app.reviews import prompts
from app.reviews.repository import ReviewStore
from app.schemas.review import MIN_INSIGHTS, MetricPoint, MetricTrend, NewReview, Review, ReviewResult


ALL_ACTIVITIES = "Tất cả hoạt động"


class ReviewError(Exception):
    def __init__(self, status_code: int, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.message = message


def usable(row: dict) -> bool:
    return row["status"] == "done" and bool((row["result"] or {}).get("canAssess"))


def metric_trends(rows: list[dict]) -> list[MetricTrend]:
    """Số đo tự động theo thời gian, mỗi (hoạt động, khóa số đo) một chuỗi — không trộn
    số lần nhảy của hai hoạt động khác nhau. rows đã sắp theo thời gian."""
    many = len({r["activity_ref"] for r in rows}) > 1
    trends: dict[tuple[str, str], MetricTrend] = {}
    for row in rows:
        evidence = row.get("evidence") or {}
        if not evidence.get("available"):
            continue
        ref, title = row["activity_ref"], row["context"]["activity"]["title"]
        for m in evidence.get("metrics", []):
            trend = trends.setdefault((ref, m["key"]), MetricTrend(
                key=f"{ref}:{m['key']}" if many else m["key"],
                label=f"{m['label']} – {title}" if many else m["label"],
                unit=m["unit"],
                points=[],
            ))
            trend.points.append(MetricPoint(insight_id=row["id"], at=row["created_at"], value=m["value"]))
    for trend in trends.values():
        if len(trend.points) > 1:
            trend.change = round(trend.points[-1].value - trend.points[0].value, 2)
    return list(trends.values())


def create_review(new: NewReview, insights: InsightStore, reviews: ReviewStore,
                  writer: TextGenerator) -> dict:
    ids = sorted(set(new.insight_ids))
    if len(ids) < MIN_INSIGHTS:
        raise ReviewError(422, f"Cần ít nhất {MIN_INSIGHTS} video để đánh giá tổng hợp")
    rows = insights.get_many(ids)
    # Không lộ nhận xét của bé khác dù đoán được id
    if len(rows) != len(ids) or any(r["child_id"] != new.child_id for r in rows):
        raise ReviewError(404, "Không tìm thấy video đã phân tích")
    if not all(usable(r) for r in rows):
        raise ReviewError(422, "Chỉ đánh giá được những video AI đã nhận xét xong")
    groups = {r["activity_group"] for r in rows}

    existing = reviews.find(new.child_id, ids, prompts.PROMPT_VERSION)
    if existing is not None:
        return existing

    rows.sort(key=lambda r: r["created_at"])
    refs = {r["activity_ref"] for r in rows}
    latest = rows[-1]["context"]
    if len(refs) == 1:
        title = latest["activity"]["title"]
    elif len(groups) == 1:
        title = f"Nhóm {latest['criteria']['name']}"
    else:
        title = ALL_ACTIVITIES
    try:
        analysis = writer.generate_text(
            prompts.SYSTEM_PROMPT, prompts.review_text(rows, title), prompts.OUTPUT_SCHEMA,
            ReviewResult, prompts.PROMPT_VERSION,
        )
    except TransientLLMError:
        raise ReviewError(503, "AI đang bận, ba mẹ thử lại sau ít phút nhé") from None
    except LLMError:
        raise ReviewError(502, "Chưa tổng hợp được lúc này, ba mẹ thử lại sau nhé") from None

    return reviews.create({
        "child_id": new.child_id,
        "requested_by": new.requested_by,
        "activity_ref": refs.pop() if len(refs) == 1 else None,
        "activity_group": groups.pop() if len(groups) == 1 else None,
        "activity_title": title,
        "insight_ids": ids,
        "period_from": rows[0]["created_at"],
        "period_to": rows[-1]["created_at"],
        "result": analysis.result.model_dump(mode="json", by_alias=True),
        "metrics": [t.model_dump(mode="json", by_alias=True) for t in metric_trends(rows)],
        "llm_model": analysis.model,
        "prompt_version": analysis.prompt_version,
        "usage": analysis.usage,
    })


def to_review(row: dict) -> Review:
    return Review(
        id=row["id"],
        child_id=row["child_id"],
        activity_ref=row["activity_ref"],
        activity_group=row.get("activity_group"),
        activity_title=row["activity_title"],
        insight_ids=row["insight_ids"],
        period_from=row["period_from"],
        period_to=row["period_to"],
        result=row["result"],
        metrics=row["metrics"],
        created_at=row["created_at"],
    )


def belongs_to(row: dict | None, child_id: UUID) -> bool:
    return row is not None and row["child_id"] == child_id
