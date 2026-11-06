"""Bé lớn khôn: deterministic CDC milestone-tracking result engine, v1.0.0.

Reference implementation for integration tests, NOT a diagnostic/screening tool.
Production must validate trusted published set/revisions and reviewed mappings server-side.
"""
from __future__ import annotations
from datetime import date
from typing import Any

AGE_MONTHS = (2, 4, 6, 9, 12, 15, 18, 24, 30, 36, 48, 60)
ANSWERS = {"achieved", "not_yet", "not_observed"}
RULES_VERSION = "1.0.0"


class RuleValidationError(ValueError):
    def __init__(self, code: str, detail: str):
        self.code = code
        super().__init__(f"{code}: {detail}")


def add_calendar_months(d: date, n: int) -> date:
    """Month anniversaries: clamp day to last day of target month."""
    import calendar
    y, m = divmod(d.year * 12 + (d.month - 1) + n, 12)
    m += 1
    return date(y, m, min(d.day, calendar.monthrange(y, m)[1]))


def age_selection(*, birth_date: str, assessment_date: str,
                  born_preterm: bool = False, age_basis: str = "chronological",
                  due_date: str | None = None, clinician_guidance_confirmed: bool = False) -> dict[str, Any]:
    """Selects one CDC checklist at or below age; never applies correction silently.

    60-month checkpoint is eligible on the exact 5th birthday only under current
    app scope. Any grace period after the fifth birthday requires a product decision.
    """
    try:
        dob, now = date.fromisoformat(birth_date), date.fromisoformat(assessment_date)
    except (ValueError, TypeError):
        raise RuleValidationError("INVALID_DATE", "Dates must be valid YYYY-MM-DD")
    if now < dob:
        raise RuleValidationError("FUTURE_BIRTH_DATE", "Assessment predates birth")
    max_date = add_calendar_months(dob, 60)
    if now > max_date:
        raise RuleValidationError("OUT_OF_APP_AGE_RANGE", "New assessment beyond 5th birthday is not allowed")
    under_24_months = now < add_calendar_months(dob, 24)
    if born_preterm and under_24_months and age_basis == "chronological" and not clinician_guidance_confirmed:
        raise RuleValidationError("AGE_GUIDANCE_REQUIRED", "Ask healthcare provider how to use checklists for preterm child")
    if age_basis not in {"chronological", "corrected_clinician_guided"}:
        raise RuleValidationError("AGE_BASIS_INVALID", "Unsupported age basis")
    if age_basis == "corrected_clinician_guided":
        if not (born_preterm and under_24_months and clinician_guidance_confirmed and due_date):
            raise RuleValidationError("CORRECTED_AGE_NOT_CONFIRMED", "Use only with preterm child <24 mo and provider guidance")
        try:
            anchor = date.fromisoformat(due_date)
        except ValueError:
            raise RuleValidationError("INVALID_DUE_DATE", "Due date must be YYYY-MM-DD")
        if anchor < dob:
            raise RuleValidationError("DUE_DATE_REQUIRES_REVIEW", "Due date predates birth: check data")
    else:
        anchor = dob
    eligible = [m for m in AGE_MONTHS if add_calendar_months(anchor, m) <= now]
    selected = eligible[-1] if eligible else None
    return {"selected_age_months": selected, "age_basis": age_basis,
            "is_eligible": selected is not None, "assessment_date": now.isoformat()}


def evaluate(*, expected_question_ids: list[str], answers: dict[str, str],
             regression: str | None, caregiver_concern: str | None,
             mode: str = "complete", question_set_age_months: int | None = None,
             question_set_version: str = "draft", content_version: str = "pending",
             environment: str = "sandbox", release_gate: dict[str, bool] | None = None,
             domain_by_question: dict[str, str] | None = None) -> dict[str, Any]:
    """Evaluate a FROZEN, server-validated question-set snapshot.

    expected_question_ids and release_gate must be read from trusted backend,
    not accepted from the untrusted mobile client directly.
    """
    if environment not in {"sandbox", "production"}:
        raise RuleValidationError("INVALID_ENVIRONMENT", "Unknown environment")
    if mode not in {"draft", "complete"}:
        raise RuleValidationError("INVALID_MODE", "Unknown evaluation mode")
    if question_set_age_months is not None and question_set_age_months not in AGE_MONTHS:
        raise RuleValidationError("INVALID_AGE_SET", "Age not in CDC milestone schedule")
    if not expected_question_ids or len(expected_question_ids) != len(set(expected_question_ids)):
        raise RuleValidationError("INVALID_SET_SNAPSHOT", "Empty or duplicate question IDs")
    expected = set(expected_question_ids)
    if not isinstance(answers, dict):
        raise RuleValidationError("INVALID_ANSWERS", "Answers must be a map")
    if set(answers) - expected:
        raise RuleValidationError("UNKNOWN_QUESTION", "Answers include an unknown question ID")
    if any(x not in ANSWERS for x in answers.values()):
        raise RuleValidationError("INVALID_OPTION", "Answer must be achieved/not_yet/not_observed")
    if regression not in {None, "yes", "no", "unsure"}:
        raise RuleValidationError("INVALID_REGRESSION_VALUE", "Expected yes/no/unsure")
    if caregiver_concern not in {None, "yes", "no"}:
        raise RuleValidationError("INVALID_CONCERN_VALUE", "Expected yes/no")
    if domain_by_question and (set(domain_by_question) != expected):
        raise RuleValidationError("INVALID_DOMAIN_MAPPING", "Map must cover exactly snapshot question IDs")
    if environment == "production":
        required = ("question_bank_approved", "question_set_published", "comment_mapping_approved", "advice_mapping_approved", "clinical_signoff", "media_rights_approved")
        if not release_gate or not all(release_gate.get(x) is True for x in required):
            raise RuleValidationError("RELEASE_GATE_BLOCKED", "All approvals must be verified server-side")
    missing = [qid for qid in expected_question_ids if qid not in answers]
    if mode == "draft":
        return {"assessment_status": "draft", "missing_question_ids": missing,
                "answers_recorded": len(answers), "total": len(expected_question_ids),
                "result": None, "rules_version": RULES_VERSION}
    if missing or regression is None or caregiver_concern is None:
        raise RuleValidationError("INCOMPLETE_ASSESSMENT", "All answers and two end-of-checklist questions required")

    by_answer = {v: [qid for qid in expected_question_ids if answers[qid] == v] for v in ANSWERS}
    achieved, not_yet, not_observed = [by_answer[v] for v in ("achieved", "not_yet", "not_observed")]
    flags = []
    if regression == "yes": flags.append("SKILL_REGRESSION_REPORTED")
    elif regression == "unsure": flags.append("REGRESSION_UNCERTAIN")
    if not_yet: flags.append("MILESTONE_NOT_RECORDED")
    if caregiver_concern == "yes": flags.append("CAREGIVER_CONCERN")
    if not_observed: flags.append("OBSERVATION_INCOMPLETE")
    if not flags: flags.append("ALL_RECORDED")

    # Primary is UI priority, NOT a medical risk or severity classification.
    if "SKILL_REGRESSION_REPORTED" in flags:
        primary = "SKILL_REGRESSION_REPORTED"
        matched_rule = "R05"
    elif "MILESTONE_NOT_RECORDED" in flags:
        primary = "MILESTONE_NOT_RECORDED"
        matched_rule = "R04" if not_observed else "R02"
    elif "CAREGIVER_CONCERN" in flags or "REGRESSION_UNCERTAIN" in flags:
        primary = "CAREGIVER_CONCERN"
        matched_rule = "R06"
    elif "OBSERVATION_INCOMPLETE" in flags:
        primary = "OBSERVATION_INCOMPLETE"
        matched_rule = "R03"
    else:
        primary = "ALL_RECORDED"
        matched_rule = "R01"

    # Deduplicate shared medical recommendation; no clinical advice generated here.
    healthcare = bool(not_yet or caregiver_concern == "yes" or regression in {"yes", "unsure"})
    advice = []
    if healthcare: advice.append("ADVICE_CONTACT_HEALTHCARE")
    if not_observed: advice.append("ADVICE_OBSERVE_SKILLS")
    if not healthcare and not not_observed: advice.append("ADVICE_CONTINUE_MONITORING")
    comment = [f"COMMENT_{k}" for k in flags]

    domains = []
    if domain_by_question:
        canonical = ("gross_motor", "fine_motor", "language_communication", "cognitive", "social_emotional")
        for domain in canonical:
            ids = [qid for qid in expected_question_ids if domain_by_question[qid] == domain]
            if ids:
                domains.append({"domain": domain, "total": len(ids),
                                **{v: sum(answers[qid] == v for qid in ids) for v in ANSWERS}})
        if sum(x["total"] for x in domains) != len(expected_question_ids):
            raise RuleValidationError("INVALID_DOMAIN", "Unexpected app domain")
    result = {
        "assessment_status": "completed", "primary_result_code": primary,
        "matched_rule_id": matched_rule, "active_result_codes": flags,
        "summary": {"total": len(expected_question_ids), "achieved": len(achieved),
                    "not_yet": len(not_yet), "not_observed": len(not_observed)},
        "skills_to_note": {"not_yet_question_ids": not_yet, "not_observed_question_ids": not_observed},
        "achieved_question_ids": achieved,
        "domain_counts": domains,
        "comment_mapping_keys": comment,
        "advice_mapping_keys": advice,
        "healthcare_discussion_recommended": healthcare,
        "question_set_age_months": question_set_age_months,
        "question_set_version": question_set_version,
        "content_version": content_version,
        "rules_version": RULES_VERSION,
        "medical_diagnosis": None,
        "developmental_risk_classification": None,
    }
    assert len(achieved) + len(not_yet) + len(not_observed) == len(expected_question_ids)
    return result
