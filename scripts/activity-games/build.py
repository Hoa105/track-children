"""Dựng dữ liệu 136 trò chơi (sách "136 trò chơi cho trẻ từ 0-36 tháng") vào DB.

Đầu vào:
  - games.jsonl: nội dung đã chép tay từ bản scan (sách không có lớp chữ).
    Mỗi dòng: p (trang PDF), age, cat, title, skills, space, pose, materials,
    steps, tips, lyrics?, caption, uncertain?, photos.
    photos: [trang PDF, x0, y0, x1, y1 (% trang), bước | null]; null = ảnh chính.
  - File PDF gốc (để cắt ảnh).

Đầu ra:
  - backend/static/activities/gNNN/*.jpg
  - backend/migrations/009_activity_games.sql

Chạy: python -I scripts/activity-games/build.py "<đường dẫn PDF>"
"""

import json
import sys
import uuid
from pathlib import Path

from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
DATA = Path(__file__).with_name("games.jsonl")
STATIC = ROOT / "backend" / "static" / "activities"
MIGRATION = ROOT / "backend" / "migrations" / "009_activity_games.sql"
URL_PREFIX = "/static/activities"
NS = uuid.uuid5(uuid.NAMESPACE_URL, "track-children/activity-games")
MAX_SIDE = 1280

# Nhóm trò chơi trong sách -> activity_groups.code
GROUPS = {
    "Trò chơi vận động thô": "gross_motor",
    "Trò chơi vận động tinh": "fine_motor",
    "Trò chơi ngôn ngữ": "language",
}
# Nhóm -> developmental_domains.code (chỉ gắn nếu bảng đã có mã đó)
DOMAINS = {
    "gross_motor": ["gross_motor"],
    "fine_motor": ["fine_motor"],
    "language": ["language"],
    "cognitive_social": ["cognitive", "social_emotional"],
}


def q(value):
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def q_array(items):
    if not items:
        return "NULL"
    return "ARRAY[" + ", ".join(q(i) for i in items) + "]::text[]"


def page_image(reader, page_no, cache):
    if page_no not in cache:
        cache[page_no] = reader.pages[page_no - 1].images[0].image.convert("RGB")
    return cache[page_no]


def crop(img, x0, y0, x1, y1):
    w, h = img.size
    box = (int(w * x0 / 100), int(h * y0 / 100), int(w * x1 / 100), int(h * y1 / 100))
    out = img.crop(box)
    out.thumbnail((MAX_SIDE, MAX_SIDE))
    return out


def content_markdown(g):
    parts = ["**Kỹ năng phát triển:** " + ", ".join(g["skills"])]
    prep = [
        f"- **{label}:** {g[key]}"
        for label, key in (("Không gian", "space"), ("Tư thế", "pose"), ("Đồ dùng", "materials"))
        if g.get(key)
    ]
    if prep:
        parts.append("## Chuẩn bị\n" + "\n".join(prep))
    parts.append("## Các bước thực hiện\n" + "\n".join(f"{i}. {s}" for i, s in enumerate(g["steps"], 1)))
    if g.get("lyrics"):
        parts.append("## Lời bài hát / đồng dao\n" + g["lyrics"])
    if g["tips"]:
        parts.append("## Hướng dẫn của chuyên gia\n" + "\n".join(f"- {t}" for t in g["tips"]))
    if g.get("caption"):
        parts.append(f"> {g['caption']}")
    parts.append(f"_Nguồn: 136 trò chơi cho trẻ từ 0-36 tháng, {g['cat'].lower()}._")
    return "\n\n".join(parts)


def material_items(text):
    if not text or text == "Không có.":
        return []
    return [s.strip(" .") for s in text.rstrip(".").split(", ") if s.strip(" .")]


def main(pdf_path):
    games = [json.loads(line) for line in DATA.read_text(encoding="utf-8").splitlines() if line.strip()]
    reader = PdfReader(pdf_path)
    cache = {}
    sql = [
        "-- =====================================================================",
        "-- 009 – Kho hoạt động: 136 trò chơi cho trẻ 0-36 tháng (kèm ảnh)",
        "-- Sinh tự động bởi scripts/activity-games/build.py từ games.jsonl. Không sửa tay.",
        "-- Ảnh: backend/static/activities/gNNN/ (phục vụ ở /static/activities/...).",
        "-- Trò chơi có ghi chú 'uncertain' (scan thiếu / sách in nhầm) để status = 'draft'.",
        "-- =====================================================================",
        "",
    ]

    for n, g in enumerate(games, 1):
        key = f"g{n:03d}"
        act_id = uuid.uuid5(NS, key)
        folder = STATIC / key
        folder.mkdir(parents=True, exist_ok=True)

        media, step_images, thumb = [], {}, None
        for idx, (page, x0, y0, x1, y1, step) in enumerate(g["photos"]):
            name = "main.jpg" if step is None else f"step-{step}.jpg"
            crop(page_image(reader, page, cache), x0, y0, x1, y1).save(folder / name, quality=82, optimize=True)
            url = f"{URL_PREFIX}/{key}/{name}"
            if step is None:
                thumb = thumb or url
            else:
                step_images[step] = url
            media.append((url, g["caption"] if step is None else f"Bước {step}", idx))
        thumb = thumb or (media[0][0] if media else None)

        group = GROUPS.get(g["cat"], "cognitive_social")
        status = "draft" if g.get("uncertain") else "published"
        goal = "Kỹ năng phát triển: " + ", ".join(g["skills"]) + "."
        summary = g["caption"] or goal
        a_from, a_to = g["age"]

        sql.append(f"-- {key}: {g['title']} (trang PDF {', '.join(map(str, g['p']))})")
        if g.get("uncertain"):
            sql.append(f"-- Cần duyệt: {g['uncertain']}")
        sql.append(
            "INSERT INTO activity.activities (id, title, summary, content, activity_type, age_from_months, "
            "age_to_months, materials, material_items, thumbnail_url, status, published_at, group_id, goal, "
            "needs_adult, lyrics)\n"
            f"SELECT {q(act_id)}, {q(g['title'])}, {q(summary)}, {q(content_markdown(g))}, 'play', {a_from}, {a_to},\n"
            f"       {q(g['materials'])}, {q_array(material_items(g['materials']))}, {q(thumb)}, '{status}', "
            f"{'now()' if status == 'published' else 'NULL'},\n"
            f"       (SELECT id FROM activity.activity_groups WHERE code = '{group}'), {q(goal)}, true, {q(g.get('lyrics'))};"
        )
        for i, text in enumerate(g["steps"], 1):
            sql.append(
                "INSERT INTO activity.activity_steps (activity_id, step_number, instruction, image_url) VALUES "
                f"({q(act_id)}, {i}, {q(text)}, {q(step_images.get(i))});"
            )
        for url, caption, order in media:
            sql.append(
                "INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order) VALUES "
                f"({q(act_id)}, 'image', {q(url)}, {q(caption[:300] if caption else None)}, {order});"
            )
        codes = ", ".join(q(c) for c in DOMAINS[group])
        sql.append(
            "INSERT INTO activity.activity_domains (activity_id, domain_id) "
            f"SELECT {q(act_id)}, id FROM criteria.developmental_domains WHERE code IN ({codes});"
        )
        sql.append("")

    MIGRATION.write_text("\n".join(sql), encoding="utf-8")
    print(f"{len(games)} trò chơi, {sum(len(g['photos']) for g in games)} ảnh -> {MIGRATION.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
