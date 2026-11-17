"""API nội bộ cho đánh giá tổng hợp — chỉ backend gọi (X-Internal-Token)."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.insights.repository import InsightStore
from app.insights.router import get_store, require_internal
from app.llm.client import TextGenerator
from app.reviews import service
from app.reviews.repository import ReviewStore
from app.schemas.review import NewReview, Review


def get_review_store(request: Request) -> ReviewStore:
    return request.app.state.review_store


def get_writer(request: Request) -> TextGenerator:
    return request.app.state.review_writer


router = APIRouter(prefix="/internal", tags=["internal: progress reviews"],
                   dependencies=[Depends(require_internal)])


@router.post("/progress-reviews", response_model=Review, status_code=status.HTTP_201_CREATED)
def create_review(
    new: NewReview,
    insights: InsightStore = Depends(get_store),
    reviews: ReviewStore = Depends(get_review_store),
    writer: TextGenerator = Depends(get_writer),
):
    """Gom các nhận xét video đã xong → nhận xét tổng hợp. Cùng tập video thì trả lại kết quả cũ."""
    try:
        row = service.create_review(new, insights, reviews, writer)
    except service.ReviewError as e:
        raise HTTPException(e.status_code, e.message) from None
    return service.to_review(row)


@router.get("/children/{child_id}/progress-reviews", response_model=list[Review])
def list_reviews(child_id: UUID, activity_ref: str | None = None,
                 reviews: ReviewStore = Depends(get_review_store)):
    return [service.to_review(r) for r in reviews.list_for_child(child_id, activity_ref)]


@router.get("/children/{child_id}/progress-reviews/{review_id}", response_model=Review)
def get_review(child_id: UUID, review_id: UUID, reviews: ReviewStore = Depends(get_review_store)):
    row = reviews.get(review_id)
    if not service.belongs_to(row, child_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy")
    return service.to_review(row)
