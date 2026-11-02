"""Daily job: python -m scripts.deliver_growth_reminders (from backend)."""
from app.features.growth.reminders import deliver_due

if __name__ == "__main__":
    deliver_due()
