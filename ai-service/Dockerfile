FROM python:3.12-slim

# OpenCV (kéo theo bởi mediapipe) cần libGL / glib; MediaPipe Tasks cần EGL / GLES.
# ffmpeg: chuyển mã video OpenCV không giải mã được (AV1, một số HEVC).
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 libegl1 libgles2 ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY scripts ./scripts
# Chỉ phần tải model, để sửa code không làm tải lại model
COPY app/__init__.py ./app/__init__.py
COPY app/pose/__init__.py app/pose/model_files.py ./app/pose/
# Tải sẵn model nếu mạng lúc build cho phép; lỗi DNS khi build không chặn image,
# service sẽ tự tải khi khởi động (app/pose/model_files.py)
RUN python scripts/download_models.py /app/models \
    || echo "WARNING: chưa tải được model MediaPipe, sẽ tải khi khởi động"
COPY app ./app

EXPOSE 8001
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
