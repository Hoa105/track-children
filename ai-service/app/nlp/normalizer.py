def normalize_text(text: str) -> str:
    """Return normalized input for downstream NLP rules."""
    return " ".join(text.strip().lower().split())
