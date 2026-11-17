"""Tải model MediaPipe cho giai đoạn 2 (đo vận động).

    python scripts/download_models.py [thư_mục]   # mặc định ./models

ai-service cũng tự tải khi khởi động nếu thiếu (app/pose/model_files.py).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.pose.model_files import URLS, download  # noqa: E402


def main() -> None:
    target = Path(sys.argv[1] if len(sys.argv) > 1 else "models")
    for name in URLS:
        print(f"Downloading {name}...")
        download(target / name)
    print("Done.")


if __name__ == "__main__":
    main()
