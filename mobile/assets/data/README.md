# WHO BMI-for-age

## Growth chart overlays

`who_growth.json` supplies all four charts with monthly rows `[month, -2 SD, median, +2 SD]` for boys and girls, 0–60 months. Download sources (including query versions) are retained in the JSON. Recreate with `python tool/import_who_growth.py` after importing BMI. The importer selects columns by header, since height/head workbooks have an extra `SD` column.

Official source pages:

- https://www.who.int/tools/child-growth-standards/standards/weight-for-age
- https://www.who.int/tools/child-growth-standards/standards/length-height-for-age
- https://www.who.int/tools/child-growth-standards/standards/head-circumference-for-age

Charts interpolate rounded monthly values linearly for display, sample the visible date range weekly plus endpoints, and plot both child and WHO on the same date/unit scales. The length-based 24-month row is used approaching age two; the height-based row is used from the second birthday. Reference paths are split there rather than smoothing across the change. No extrapolation before birth or beyond the fifth birthday. The BMI table card below the chart continues to show the completed-month table row (without interpolation).

The shaded area is explicitly labeled -2 to +2 SD and is a statistical reference, not a diagnostic normal range. The child line remains visible if metadata is missing or dates are outside reference coverage. Shared date of birth/sex preferences can be edited from each metric tab; preview charts use a distinct example birth date eight calendar months before the latest plotted date.

Source: https://www.who.int/toolkits/child-growth-standards/standards/body-mass-index-for-age-bmi-for-age

`who_bmi.json` contains the numeric monthly tables for boys and girls, birth–2 years and 2–5 years, downloaded from WHO on 2026-10-15. Column order: Month, L, M, S, SD3neg, SD2neg, SD1neg, SD0, SD1, SD2, SD3. Source filenames are stored in the JSON. Recreate with `python tool/import_who_bmi.py` (requires openpyxl and curl).

The overlapping 24-month rows are intentionally retained: the lookup uses the last (2–5 years, standing height) row at 24 months. Lookup uses completed months at measurement date, without interpolation. The displayed values are WHO's rounded table thresholds, not a computed clinical Z-score or diagnosis.

Under 24 months, BMI reference uses recumbent length; from 24 months, standing height. Measurements taken in the other position require conversion before comparison. The current UI reminds users of this requirement and does not automatically correct measurements or assign nutritional classifications.

The preview explicitly represents a boy aged 8 months. Real measurements require a separately selected date of birth and sex, saved locally for the current child name until profile integration supplies a stable child ID and metadata. Preview metadata is never saved as the real child's metadata.
