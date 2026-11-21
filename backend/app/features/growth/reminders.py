"""Compatibility entry point for the existing daily job."""
def deliver_due():
    from scripts.deliver_notifications import run
    run()
