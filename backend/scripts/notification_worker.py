"""Long-lived scheduler for Docker/Windows services."""
import logging
import time
from scripts.deliver_notifications import run

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    while True:
        try:
            run()
        except Exception:
            logging.exception('Notification scheduler failed; retrying in 60 seconds')
        time.sleep(60)
