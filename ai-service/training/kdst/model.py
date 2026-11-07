"""ST-GCN gọn: phần trích đặc trưng dùng chung + 12 đầu chấm điểm (mỗi bài một đầu, 3 mức)
+ 1 đầu phụ nhận diện bài.

Đầu nhận diện bài vừa giúp phần dùng chung học chuyển động tốt hơn, vừa để kiểm tra
"video có đúng bài phụ huynh chọn không" — sai bài thì không chấm.
"""

import numpy as np
import torch
from torch import nn

from app.kdst.skeleton import EDGES, NUM_JOINTS


def adjacency(num_joints: int = NUM_JOINTS) -> torch.Tensor:
    """3 phân vùng (bản thân, cạnh, cạnh lân cận bậc 2), chuẩn hóa D^-1/2 A D^-1/2."""
    a1 = np.zeros((num_joints, num_joints), dtype=np.float32)
    for i, j in EDGES:
        a1[i, j] = a1[j, i] = 1
    a2 = ((a1 @ a1) > 0).astype(np.float32)
    np.fill_diagonal(a2, 0)
    a2 = a2 * (1 - a1)

    def norm(a):
        d = a.sum(axis=1)
        d_inv = np.where(d > 0, d ** -0.5, 0)
        return d_inv[:, None] * a * d_inv[None, :]

    return torch.tensor(np.stack([np.eye(num_joints, dtype=np.float32), norm(a1), norm(a2)]))


class GraphConv(nn.Module):
    def __init__(self, c_in: int, c_out: int, a: torch.Tensor):
        super().__init__()
        self.register_buffer("a", a)
        self.importance = nn.Parameter(torch.ones_like(a))  # trọng số cạnh học được
        self.conv = nn.Conv2d(c_in, c_out * a.shape[0], 1)
        self.k = a.shape[0]

    def forward(self, x):  # (N, C, T, V)
        n, _, t, v = x.shape
        x = self.conv(x).view(n, self.k, -1, t, v)
        return torch.einsum("nkctv,kvw->nctw", x, self.a * self.importance)


class Block(nn.Module):
    def __init__(self, c_in: int, c_out: int, a: torch.Tensor, stride: int = 1):
        super().__init__()
        self.gcn = GraphConv(c_in, c_out, a)
        self.tcn = nn.Sequential(
            nn.BatchNorm2d(c_out),
            nn.ReLU(inplace=True),
            nn.Conv2d(c_out, c_out, (9, 1), (stride, 1), (4, 0)),
            nn.BatchNorm2d(c_out),
        )
        if c_in == c_out and stride == 1:
            self.residual = nn.Identity()
        else:
            self.residual = nn.Sequential(nn.Conv2d(c_in, c_out, 1, (stride, 1)), nn.BatchNorm2d(c_out))
        self.relu = nn.ReLU(inplace=True)

    def forward(self, x):
        return self.relu(self.tcn(self.gcn(x)) + self.residual(x))


class KdstNet(nn.Module):
    # Độ rộng nhỏ để train được bằng CPU (khoảng 0,5 triệu tham số)
    def __init__(self, num_items: int = 12, num_scores: int = 3, in_channels: int = 3,
                 widths: tuple[int, ...] = (32, 32, 64, 64, 128, 128), dropout: float = 0.3):
        super().__init__()
        a = adjacency()
        self.num_items, self.num_scores = num_items, num_scores
        self.data_bn = nn.BatchNorm1d(in_channels * NUM_JOINTS)
        layers, c = [], in_channels
        for i, w in enumerate(widths):
            stride = 2 if i > 0 and w != widths[i - 1] else 1
            layers.append(Block(c, w, a, stride))
            c = w
        self.backbone = nn.Sequential(*layers)
        self.dropout = nn.Dropout(dropout)
        self.score_head = nn.Linear(c, num_items * num_scores)
        self.item_head = nn.Linear(c, num_items)

    def forward(self, x):
        """x: (N, 3, T, V) → (score_logits (N, items, 3), item_logits (N, items))."""
        n, c, t, v = x.shape
        x = self.data_bn(x.permute(0, 1, 3, 2).reshape(n, c * v, t)).view(n, c, v, t).permute(0, 1, 3, 2)
        feat = self.dropout(self.backbone(x).mean(dim=(2, 3)))
        return self.score_head(feat).view(n, self.num_items, self.num_scores), self.item_head(feat)
