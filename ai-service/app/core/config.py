from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = (
        "postgresql://track_children:track_children_dev@localhost:5434/track_children_ai"
    )
    # Backend gửi kèm header X-Internal-Token; để trống = chặn mọi request nội bộ.
    internal_token: str = ""

    # Nhà cung cấp AI xem video: "gemini" (mặc định) hoặc "claude"
    llm_provider: str = "gemini"
    # Gemini API (Google AI Studio)
    gemini_api_key: str = ""
    gemini_model: str = "gemini-3.8-flash,gemini-3.5-flash-lite"  # danh sách dự phòng
    # Claude API. Khóa đọc từ ANTHROPIC_API_KEY (SDK tự lấy).
    llm_model: str = "claude-opus-5-5"
    llm_effort: str = "medium"  # low | medium | high
    llm_max_frames: int = 16  # số khung hình gửi cho AI mỗi video
    llm_frame_max_side: int = 768  # px, cạnh dài nhất của khung hình gửi đi

    # Video tạm — xóa ngay khi phân tích xong (thành công hoặc hết lượt thử)
    video_dir: str = "./data/videos"
    max_video_bytes: int = 150 * 1024 * 1024
    min_video_seconds: float = 2
    max_video_seconds: float = 90

    # Worker chạy trong cùng tiến trình API
    worker_enabled: bool = True
    worker_poll_seconds: float = 2
    max_attempts: int = 3
    stale_running_minutes: int = 15

    # Giai đoạn 2: đo vận động bằng MediaPipe (scripts/download_models.py tải model)
    pose_enabled: bool = True
    pose_model_path: str = "./models/pose_landmarker_full.task"
    hand_model_path: str = "./models/hand_landmarker.task"
    pose_sample_fps: float = 10

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
