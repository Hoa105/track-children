"""Đọc A/B/C_skel.zip của dataset → một file .npz đã chuẩn hóa, chia train/val/test THEO TRẺ.

    python -m training.kdst.prepare --data-dir C:/ml/kdst-data --out C:/ml/kdst-data/kdst_v1.npz

Mỗi file JSON (1 trẻ × 1 bài × 1 lần thử × 1 góc quay) thành 1 mẫu. Chuỗi được lưu ở
STORE_LEN khung để lúc train còn cắt/thu đoạn ngẫu nhiên rồi mới lấy mẫu về SEQ_LEN.
"""

import argparse
import sys
import json
import re
import zipfile
from collections import Counter
from pathlib import Path

import numpy as np

from app.kdst.items import ITEM_INDEX, item_code
from app.kdst.skeleton import from_body25, normalize, pick_child, resample

STORE_LEN = 128
NAME = re.compile(r"(?P<child>[ABC]\d+)_GMS_(?P<act>\d)_(?P<trial>\d+)_(?P<view>\d)\.json$")
SPLIT_SEED = 100
SPLITS = {"train": 0.70, "val": 0.15, "test": 0.15}


def load_file(raw: bytes) -> tuple[np.ndarray, int] | None:
    data = json.loads(raw)
    frames = [
        [from_body25(s["pose"], s["score"]) for s in frame["skeleton"]]
        for frame in sorted(data["data"], key=lambda f: f["frame_index"])
    ]
    seq = normalize(pick_child(frames))
    if seq is None:
        return None
    return resample(seq, STORE_LEN), int(data["label_index"])


def split_children(children: list[str]) -> dict[str, str]:
    """Chia theo trẻ để cùng một bé không vừa nằm ở train vừa ở test."""
    rng = np.random.default_rng(SPLIT_SEED)
    order = sorted(children)
    rng.shuffle(order)
    n_train = round(len(order) * SPLITS["train"])
    n_val = round(len(order) * SPLITS["val"])
    return {
        c: "train" if i < n_train else "val" if i < n_train + n_val else "test"
        for i, c in enumerate(order)
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")  # console Windows mặc định cp1252, không in được tiếng Việt

    xs, items, scores, views, trials, children = [], [], [], [], [], []
    skipped = Counter()
    for group in "ABC":
        with zipfile.ZipFile(args.data_dir / f"{group}_skel.zip") as zf:
            names = [n for n in zf.namelist() if n.endswith(".json")]
            for i, name in enumerate(names):
                m = NAME.search(name)
                if not m:
                    skipped["bad_name"] += 1
                    continue
                loaded = load_file(zf.read(name))
                if loaded is None:
                    skipped["no_skeleton"] += 1
                    continue
                seq, label = loaded
                xs.append(seq)
                items.append(ITEM_INDEX[item_code(group, int(m["act"]))])
                scores.append(label)
                views.append(int(m["view"]))
                trials.append(int(m["trial"]))
                children.append(m["child"])
                if i % 1000 == 0:
                    print(f"{group}: {i}/{len(names)}")

    split_of = {}
    for group in "ABC":
        split_of.update(split_children(sorted({c for c in children if c[0] == group})))
    split = np.array([split_of[c] for c in children])

    args.out.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(
        args.out,
        x=np.stack(xs).astype(np.float32),  # (N, STORE_LEN, 21, 3)
        item=np.array(items, dtype=np.int64),
        score=np.array(scores, dtype=np.int64),
        view=np.array(views, dtype=np.int64),
        trial=np.array(trials, dtype=np.int64),
        child=np.array(children),
        split=split,
    )
    print(f"Đã lưu {len(xs)} mẫu → {args.out}; bỏ qua: {dict(skipped)}")
    for name in SPLITS:
        mask = split == name
        print(f"  {name}: {mask.sum()} mẫu, {len({c for c, s in zip(children, split) if s == name})} trẻ")


if __name__ == "__main__":
    main()
