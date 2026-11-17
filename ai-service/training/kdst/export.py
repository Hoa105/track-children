"""Xuất best.pt → ONNX + meta.json cho ai-service, rồi kiểm tra ONNX ra cùng kết quả với PyTorch.

    python -m training.kdst.export --run C:/ml/runs/kdst_v1 --out models/kdst --version kdst_v1

ai-service chỉ cần onnxruntime (CPU), không cần PyTorch.
Đầu vào  "skeleton": (N, 3, 64, 21) float32 — kết quả của skeleton.normalize/resample/to_model_input
Đầu ra   "score_logits": (N, 12, 3) — lấy hàng của bài phụ huynh chọn, softmax → xác suất 0/1/2
         "item_logits":  (N, 12)    — model nghĩ video là bài nào
"""

import argparse
import sys
import json
from pathlib import Path

import numpy as np
import torch

from app.kdst.items import ITEMS, SCORE_LABELS
from training.kdst.model import KdstNet
from app.kdst.skeleton import JOINTS, NORMALIZATION_VERSION, SEQ_LEN


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--min-confidence", type=float, default=0.7)
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")  # console Windows mặc định cp1252, không in được tiếng Việt

    model = KdstNet(num_items=len(ITEMS))
    model.load_state_dict(torch.load(args.run / "best.pt", map_location="cpu"))
    model.eval()

    args.out.mkdir(parents=True, exist_ok=True)
    onnx_path = args.out / f"{args.version}.onnx"
    dummy = torch.randn(1, 3, SEQ_LEN, len(JOINTS))
    torch.onnx.export(
        model, (dummy,), onnx_path,
        input_names=["skeleton"], output_names=["score_logits", "item_logits"],
        dynamic_axes={"skeleton": {0: "n"}, "score_logits": {0: "n"}, "item_logits": {0: "n"}},
        opset_version=17, dynamo=False,
    )

    import onnxruntime as ort

    x = torch.randn(4, 3, SEQ_LEN, len(JOINTS))
    with torch.no_grad():
        ref = [t.numpy() for t in model(x)]
    got = ort.InferenceSession(str(onnx_path)).run(None, {"skeleton": x.numpy()})
    diff = max(float(np.abs(a - b).max()) for a, b in zip(ref, got))
    assert diff < 1e-3, f"ONNX lệch PyTorch: {diff}"

    report = json.loads((args.run / "report.json").read_text(encoding="utf-8"))
    meta = {
        "version": args.version,
        "normalization_version": NORMALIZATION_VERSION,
        "seq_len": SEQ_LEN,
        "joints": list(JOINTS),
        "items": [{"code": it.code, "name": it.name_vi,
                   "age_from_months": it.age_from_months, "age_to_months": it.age_to_months}
                  for it in ITEMS],
        "score_labels": list(SCORE_LABELS),
        "min_confidence": args.min_confidence,
        "test": {k: report["test"][k] for k in ("accuracy", "macro_f1", "item_recognition_accuracy")},
    }
    (args.out / f"{args.version}.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Đã xuất {onnx_path} ({onnx_path.stat().st_size / 1e6:.1f} MB), lệch tối đa {diff:.2e}")


if __name__ == "__main__":
    main()
