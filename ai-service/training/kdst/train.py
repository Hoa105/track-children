"""Train KdstNet trên file .npz do training.kdst.prepare tạo.

    python -m training.kdst.train --data C:/ml/kdst-data/kdst_v1.npz --out C:/ml/runs/kdst_v1

Chọn checkpoint tốt nhất theo macro-F1 trung bình các bài trên tập val, rồi đánh giá
một lần trên tập test → report.json.
"""

import argparse
import sys
import json
import math
import time
from pathlib import Path

import numpy as np
import torch
from torch import nn

from app.kdst.items import ITEMS
from training.kdst.metrics import evaluate
from training.kdst.model import KdstNet
from app.kdst.skeleton import FLIP_PERM, NORMALIZATION_VERSION, SEQ_LEN


def augment(x: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """x: (B, STORE_LEN, V, 3) → (B, SEQ_LEN, V, 3), có cắt đoạn, lật, xoay, co giãn, che khớp."""
    b, store_len, v, _ = x.shape
    out = np.empty((b, SEQ_LEN, v, 3), dtype=np.float32)
    for i in range(b):
        length = int(store_len * rng.uniform(0.8, 1.0))
        start = rng.integers(0, store_len - length + 1)
        idx = np.linspace(start, start + length - 1, SEQ_LEN).round().astype(int)
        seq = x[i, idx].copy()
        if rng.random() < 0.5:  # lật ngang: đổi trái ↔ phải
            seq = seq[:, list(FLIP_PERM)]
            seq[:, :, 0] *= -1
        angle = np.deg2rad(rng.uniform(-10, 10))
        rot = np.array([[np.cos(angle), -np.sin(angle)], [np.sin(angle), np.cos(angle)]], dtype=np.float32)
        seq[:, :, :2] = (seq[:, :, :2] @ rot.T) * rng.uniform(0.9, 1.1)
        seq[:, :, :2] += rng.normal(0, 0.01, size=seq[:, :, :2].shape)
        drop = rng.random(v) < 0.05  # mất hẳn vài khớp (bị che, ra ngoài khung)
        seq[:, drop, 2] = 0
        seq[:, :, :2] *= seq[:, :, 2:3]
        out[i] = seq
    return out


def pick_device() -> torch.device:
    """GPU nếu thật sự dùng được — is_available() có thể True dù driver từ chối cấp thiết bị.

    Muốn ép chạy CPU: đặt CUDA_VISIBLE_DEVICES=-1 trước khi chạy.
    """
    if torch.cuda.is_available():
        try:
            torch.zeros(1, device="cuda").sum().item()
            return torch.device("cuda")
        except RuntimeError as e:
            print(f"Không dùng được GPU ({e.__class__.__name__}), chuyển sang CPU")
    return torch.device("cpu")


def eval_input(x: np.ndarray) -> np.ndarray:
    idx = np.linspace(0, x.shape[1] - 1, SEQ_LEN).round().astype(int)
    return x[:, idx]


def to_tensor(x: np.ndarray, device) -> torch.Tensor:
    return torch.from_numpy(np.ascontiguousarray(x.transpose(0, 3, 1, 2))).to(device)  # (B, 3, T, V)


@torch.no_grad()
def predict(model, x, item, device, batch=256):
    model.eval()
    score_probs, item_probs = [], []
    for s in range(0, len(x), batch):
        score_logits, item_logits = model(to_tensor(eval_input(x[s:s + batch]), device))
        it = torch.from_numpy(item[s:s + batch]).to(device)
        chosen = score_logits[torch.arange(len(it), device=device), it]
        score_probs.append(chosen.softmax(-1).cpu().numpy())
        item_probs.append(item_logits.softmax(-1).cpu().numpy())
    return np.concatenate(score_probs), np.concatenate(item_probs)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--epochs", type=int, default=35)
    parser.add_argument("--batch", type=int, default=64)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--item-loss-weight", type=float, default=0.5)
    parser.add_argument("--patience", type=int, default=10)
    parser.add_argument("--seed", type=int, default=100)
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")  # console Windows mặc định cp1252, không in được tiếng Việt

    torch.manual_seed(args.seed)
    rng = np.random.default_rng(args.seed)
    device = pick_device()
    args.out.mkdir(parents=True, exist_ok=True)

    d = np.load(args.data)
    sets = {name: {k: d[k][d["split"] == name] for k in ("x", "item", "score", "view")}
            for name in ("train", "val", "test")}
    tr = sets["train"]
    print(f"device={device}; " + ", ".join(f"{k}={len(v['item'])}" for k, v in sets.items()))

    # Trọng số lớp: căn bậc hai nghịch đảo tần suất (nhãn "steady" chiếm đa số)
    freq = np.bincount(tr["score"], minlength=3) / len(tr["score"])
    class_weight = torch.tensor((1 / np.sqrt(freq)) / (1 / np.sqrt(freq)).mean(), dtype=torch.float32, device=device)
    score_loss = nn.CrossEntropyLoss(weight=class_weight, label_smoothing=0.1)
    item_loss = nn.CrossEntropyLoss(label_smoothing=0.1)

    model = KdstNet(num_items=len(ITEMS)).to(device)
    opt = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=1e-4)
    steps_per_epoch = math.ceil(len(tr["item"]) / args.batch)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=args.lr, total_steps=args.epochs * steps_per_epoch)

    best_f1, best_epoch, history = -1.0, -1, []
    for epoch in range(1, args.epochs + 1):
        model.train()
        t0, total = time.time(), 0.0
        order = rng.permutation(len(tr["item"]))
        for s in range(0, len(order), args.batch):
            idx = order[s:s + args.batch]
            x = to_tensor(augment(tr["x"][idx], rng), device)
            item = torch.from_numpy(tr["item"][idx]).to(device)
            score = torch.from_numpy(tr["score"][idx]).to(device)
            score_logits, item_logits = model(x)
            chosen = score_logits[torch.arange(len(idx), device=device), item]
            loss = score_loss(chosen, score) + args.item_loss_weight * item_loss(item_logits, item)
            opt.zero_grad()
            loss.backward()
            opt.step()
            sched.step()
            total += loss.item() * len(idx)

        va = sets["val"]
        sp, ip = predict(model, va["x"], va["item"], device)
        val = evaluate(va["item"], va["score"], sp, ip, tr["score"], tr["item"])
        history.append({"epoch": epoch, "loss": total / len(order), "val_macro_f1": val["macro_f1"],
                         "val_accuracy": val["accuracy"], "val_item_acc": val["item_recognition_accuracy"]})
        print(f"epoch {epoch:3d} loss {total / len(order):.4f} val acc {val['accuracy']:.3f} "
              f"macroF1 {val['macro_f1']:.3f} item {val['item_recognition_accuracy']:.3f} ({time.time() - t0:.0f}s)")
        if val["macro_f1"] > best_f1:
            best_f1, best_epoch = val["macro_f1"], epoch
            torch.save(model.state_dict(), args.out / "best.pt")
        elif epoch - best_epoch >= args.patience:
            print(f"Dừng sớm: {args.patience} epoch không cải thiện")
            break

    model.load_state_dict(torch.load(args.out / "best.pt", map_location=device))
    report = {"best_epoch": best_epoch, "normalization_version": NORMALIZATION_VERSION,
              "args": {k: str(v) for k, v in vars(args).items()}, "history": history}
    for name in ("val", "test"):
        s = sets[name]
        sp, ip = predict(model, s["x"], s["item"], device)
        report[name] = evaluate(s["item"], s["score"], sp, ip, tr["score"], tr["item"])
        report[name]["per_view_accuracy"] = {
            str(v): float((sp.argmax(1) == s["score"])[s["view"] == v].mean()) for v in (1, 2, 3)
        }
    (args.out / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    t = report["test"]
    print(f"TEST: acc {t['accuracy']:.3f} (baseline {t['baseline_accuracy']:.3f}), "
          f"macroF1 {t['macro_f1']:.3f} (baseline {t['baseline_macro_f1']:.3f}), "
          f"nhận diện bài {t['item_recognition_accuracy']:.3f}")


if __name__ == "__main__":
    main()
