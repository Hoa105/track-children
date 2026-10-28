# Weight-for-age display references

## Head circumference for age

`head_for_age_curves.json` preserves WHO monthly −3, −2, median, +2, +3 SD
head-circumference thresholds in cm, separately for boys/girls at 0–60 months.
Original HCFA XLSX files are archived in `sources/`; URLs/hashes are in JSON.
Rebuild with `python mobile/tool/import_who_head_age.py`. The importer checks
all original −2/median/+2 values against `who_growth.json`. Display curves are
not child Z-score calculations or clinical classifications.

## Length/height-for-age

`stature_for_age_curves.json` contains five WHO curves (−3, −2, median, +2, +3 SD)
in cm for boys/girls, separated into recumbent length at 0–24 months and standing
height at 24–60 months. Both 24-month rows are preserved without conversion.
Original files, source URLs and hashes are retained. Rebuild with
`python mobile/tool/import_who_stature_age.py`; the importer checks every inner
threshold against the existing `who_growth.json` and validates complete domains.
These are display values, not calculated child Z-scores.

## Weight velocity (1-month increments)

`weight_velocity_1month.json` contains the original WHO −2 SD, median and +2 SD
increment values in grams for 12 intervals per sex. Source XLSX files, URLs and
SHA-256 hashes are retained. Rebuild with `python mobile/tool/import_who_weight_velocity.py`.
Source: https://www.who.int/tools/child-growth-standards/standards/weight-velocity
The original first intervals are 0–4 weeks and 4 weeks–2 months; the remaining
rows are consecutive monthly intervals through 12 months. Display shading is
not a calculated child Z-score or a velocity classification.

## Weight-for-length/height addition

Source: https://www.who.int/tools/child-growth-standards/standards/weight-for-length-height

`weight_for_stature_curves.json` preserves the original rounded WHO thresholds
at 0.5 cm intervals: 131 length rows (45–110 cm) and 111 height rows (65–120 cm)
per sex. Each row contains cm, −3 SD, −2 SD, median, +2 SD and +3 SD in kg.
Source XLSX files are archived in `sources/`; URLs and SHA-256 hashes are in the
derived JSON. Rebuild with `python mobile/tool/import_who_stature_curves.py`.
The importer validates complete domains, spacing, positive ordered thresholds.
No age-based weight table is substituted for a weight-for-stature reference.

Official source page: https://www.who.int/tools/child-growth-standards/standards/weight-for-age

`weight_for_age_curves.json` contains the WHO monthly rounded display thresholds
for boys and girls, 61 rows each (0 through 60 months inclusive). Columns:
month, −3 SD, −2 SD, median, +2 SD, +3 SD, in kg. Source URLs, versions embedded
in the query strings, and original-file SHA-256 hashes are preserved in JSON.

Original Excel files are archived under `sources/`; the app bundles only the
derived JSON. They are read without changing the workbooks. Reproduce with:

```powershell
python mobile/tool/import_who_weight_curves.py
```

The importer selects named WHO columns, validates complete consecutive months,
numeric positive ordered thresholds, and matches every −2/median/+2 value to the
existing `who_growth.json` weight tables. `weight_for_age_validation.json` records
checks, sample rows at 0/6/12/24/60 months and hashes. Flutter tests independently
validate both packaged tables, order, coverage and rejection of malformed data.

The chart joins monthly source values for display. Shading is the interval
between the labeled reference lines, never a diagnosis or a “normal” status.
The mock chart explicitly uses the boys table; sex metadata is supplied by the
repository and displayed in the legend. This is not integration with real child
profiles or a clinical assessment engine. No child Z-score, nutritional category
or velocity percentile is computed. Other WHO datasets/spec phases remain
outside this addition.
# Length velocity · two-month increments

`stature_velocity_2month.json` contains the unmodified −2 SD, median and +2 SD length increments (cm over **two months**) from the WHO boys/girls tables, for intervals 0–2 through 22–24 months. Sources are the original `sources/ttt_length_{boys,girls}_2mon_z.xlsx` files; URLs and SHA-256 hashes are embedded in JSON. Rebuild with `python mobile/tool/import_who_stature_velocity.py`.

Do not use these thresholds for one-month increments, standing height, or ages above 24 months. Display cells are centered on each interval midpoint and do not interpolate between the rolling two-month distributions. No LMS/Z-score calculation or clinical classification is added.

# Head circumference velocity · two-month increments

`head_velocity_2month.json` preserves original WHO −2 SD, median and +2 SD head-circumference increments, in cm over two months, for 11 intervals per sex (0–2 through 10–12 months). Original XLSX sources are under `sources/ttt_headc_{boys,girls}_2mon_z.xlsx`; source URLs and SHA-256 hashes are embedded in JSON. Rebuild with `python mobile/tool/import_who_head_velocity.py`.

This reference applies only to two-month head-circumference increments from birth to 12 months; it is distinct from the stature reference. No recumbent/standing restriction applies to head circumference. No Z-score algorithm or clinical classification is derived from the display band.

