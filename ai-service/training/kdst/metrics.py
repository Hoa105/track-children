"""Chỉ số đánh giá: accuracy, macro-F1, confusion matrix theo từng bài, bảng ngưỡng tin cậy."""

import numpy as np

from app.kdst.items import ITEMS


def confusion(y_true: np.ndarray, y_pred: np.ndarray, k: int = 3) -> np.ndarray:
    m = np.zeros((k, k), dtype=np.int64)
    np.add.at(m, (y_true, y_pred), 1)
    return m


def macro_f1(cm: np.ndarray) -> float:
    """Trung bình F1 các lớp có mặt trong y_true (lớp không có mẫu thật thì bỏ qua)."""
    f1s = []
    for c in range(len(cm)):
        support = cm[c].sum()
        if support == 0:
            continue
        tp = cm[c, c]
        precision = tp / cm[:, c].sum() if cm[:, c].sum() else 0.0
        recall = tp / support
        f1s.append(0.0 if precision + recall == 0 else 2 * precision * recall / (precision + recall))
    return float(np.mean(f1s)) if f1s else 0.0


def evaluate(item: np.ndarray, score: np.ndarray, score_prob: np.ndarray,
             item_prob: np.ndarray, train_score: np.ndarray, train_item: np.ndarray) -> dict:
    """score_prob: (N, 3) của đầu đúng bài; item_prob: (N, 12).

    Baseline = luôn đoán mức điểm phổ biến nhất của bài đó trong tập train.
    """
    pred = score_prob.argmax(axis=1)
    per_item = {}
    for i, it in enumerate(ITEMS):
        mask = item == i
        if not mask.any():
            continue
        cm = confusion(score[mask], pred[mask])
        majority = np.bincount(train_score[train_item == i], minlength=3).argmax()
        per_item[it.code] = {
            "n": int(mask.sum()),
            "accuracy": float((pred[mask] == score[mask]).mean()),
            "macro_f1": macro_f1(cm),
            "baseline_accuracy": float((score[mask] == majority).mean()),
            "baseline_macro_f1": macro_f1(confusion(score[mask], np.full(mask.sum(), majority))),
            "confusion": cm.tolist(),
        }

    conf = score_prob.max(axis=1)
    coverage = []
    for threshold in (0.0, 0.5, 0.6, 0.7, 0.8, 0.9):
        keep = conf >= threshold
        coverage.append({
            "threshold": threshold,
            "coverage": float(keep.mean()),
            "accuracy": float((pred[keep] == score[keep]).mean()) if keep.any() else None,
        })

    item_pred = item_prob.argmax(axis=1)
    return {
        "n": int(len(item)),
        "accuracy": float((pred == score).mean()),
        "macro_f1": float(np.mean([v["macro_f1"] for v in per_item.values()])),
        "baseline_accuracy": float(np.mean([v["baseline_accuracy"] for v in per_item.values()])),
        "baseline_macro_f1": float(np.mean([v["baseline_macro_f1"] for v in per_item.values()])),
        "item_recognition_accuracy": float((item_pred == item).mean()),
        "item_confusion": confusion(item, item_pred, len(ITEMS)).tolist(),
        "per_item": per_item,
        "confidence_coverage": coverage,
    }
