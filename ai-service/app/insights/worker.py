"""Worker nền: lấy job pending từ Postgres (FOR UPDATE SKIP LOCKED), không cần Redis.

Chạy nhiều tiến trình ai-service cũng an toàn: mỗi job chỉ một worker lấy được.
"""

import datetime as dt
import logging
import threading

from app.insights import service
from app.insights.repository import InsightStore
from app.llm.client import VideoAnalyzer

log = logging.getLogger(__name__)


class InsightWorker:
    def __init__(
        self,
        store: InsightStore,
        analyzer: VideoAnalyzer,
        options: service.ProcessOptions,
        poll_seconds: float,
        stale_after: dt.timedelta,
    ):
        self.store = store
        self.analyzer = analyzer
        self.options = options
        self.poll_seconds = poll_seconds
        self.stale_after = stale_after
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def run_once(self) -> bool:
        """Xử lý tối đa một job. True nếu đã xử lý (gọi tiếp ngay)."""
        job = self.store.claim_next()
        if job is None:
            return False
        service.process(job, self.store, self.analyzer, self.options)
        return True

    def _loop(self) -> None:
        try:
            requeued = self.store.requeue_stale(self.stale_after)
            if requeued:
                log.warning("Requeued %d stale video insight jobs", requeued)
        except Exception:  # noqa: BLE001
            log.exception("Could not requeue stale jobs")
        while not self._stop.is_set():
            try:
                busy = self.run_once()
            except Exception:  # noqa: BLE001 — mất kết nối DB…: chờ rồi thử lại
                log.exception("Video insight worker error")
                busy = False
            if not busy:
                self._stop.wait(self.poll_seconds)

    def start(self) -> None:
        self._thread = threading.Thread(target=self._loop, name="video-insight-worker", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=10)
