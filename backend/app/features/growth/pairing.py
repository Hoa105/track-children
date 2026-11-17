"""Application policy: dates (not timestamps), at most one calendar day apart."""

POLICY = "calendar-day-1-v1"


def nearest(anchor, candidates):
    valid = [r for r in candidates
             if abs((r["measured_on"] - anchor["measured_on"]).days) <= 1]
    return min(valid, key=lambda r: (
        abs((r["measured_on"] - anchor["measured_on"]).days),
        -r["measured_on"].toordinal(), str(r["id"])), default=None)


def bmi_values(values, rows):
    weight = values.get("weight")
    if weight is None:
        return values
    height = nearest(weight, [r for r in rows if r["metric"] == "height"])
    return {"weight": weight, **({"height": height} if height else {})}


def latest_pair(rows):
    relevant = [r for r in rows if r["metric"] in ("weight", "height")]
    if not relevant:
        return None, None, None
    # Prefer weight when both metrics have the latest date; same-day pairing wins.
    anchor = max(relevant, key=lambda r: (r["measured_on"], r["metric"] == "weight"))
    other = nearest(anchor, [r for r in relevant if r["metric"] != anchor["metric"]])
    if other is None:
        return anchor, None, None
    return anchor, (anchor if anchor["metric"] == "weight" else other), (anchor if anchor["metric"] == "height" else other)
