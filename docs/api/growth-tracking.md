# Parent growth tracking

The simple mobile flow uses the endpoints below under `/api/v1/children/{childId}/growth`.
Authentication and child access checks apply to every endpoint. Dates are business
calendar dates in Asia/Ho_Chi_Minh; no measurement time is requested from parents.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/tracking` | Raw measurements with IDs, profile, edit permission, pair availability; no R calculation |
| POST | `/measurements` | Create one measurement; duplicate metric/date returns 409 `MEASUREMENT_EXISTS` |
| PATCH | `/measurements/{id}` | Edit value/date/position; retains ID, cannot change metric/child |
| DELETE | `/measurements/{id}` | Soft-delete one record, invalidate dependent assessments |
| GET | `/assessment/bmi` | Latest anchored BMI assessment, missing-data state and previous assessment |
| GET | `/assessment/head` | Four-band head circumference screening |
| GET | `/reminders` | Per-user schedule and persistent in-app reminder notices |
| PUT | `/reminders/{metric}` | Enable, snooze or book a health-worker appointment |

Creation body: `{"metric":"weight","value":9.5,"measuredOn":"2026-11-01"}`.
Height additionally requires `"measurePosition":"lying"` or `"standing"`.
PATCH uses the same body without `metric`. No direct BMI write is accepted.
Writes return `measurementSaved: true` and `measurement`, without calling R after commit.

Pair policy `calendar-day-1-v1`: anchor the newest weight/height, prefer the other
metric on the same date, otherwise accept an adjacent calendar date, preferring
the later date on ties. The weight date determines BMI reference age. Historical
weight assessments accept `selectedMeasurementId` and select height relative to
that weight. Raw measurement dates are never changed. A missing latest pair does
not silently become a previous pair. Assessment results contain both source IDs,
dates, raw values, normalization, BMI, unrounded Z-score, classification, summary
and generic action. Out-of-scope ages, preterm infants, flagged inputs and engine
errors do not receive a health classification.

Parent-facing assessment only calculates the selected BMI/head input. It does not
invoke velocity, trend interpretation, cause investigation or personalized advice.
The existing legacy endpoints remain for compatibility. WHO head circumference
standards were published in 2007; this source label is intentionally retained.

Full-precision scores use the checksum-verified official anthro LMS tables,
including the restricted LMS tail for BMI. The R engine remains the input/flag
gate; rounded public-engine scores are not used as classification boundaries.

Reminder preferences: `enabled`, nullable `snoozedUntil`, nullable `appointmentOn`.
For healthy-child product defaults, weight/height reminders use 1 month at age
14 days–<6 months, 2 months at 6–<12 months, 3 months at 12–<60 months. Under 14
days and head circumference use a booked appointment only. Dates are derived
independently from each metric's latest actual measurement. No-record state is
an invitation to record, not an invented missed appointment. A booked date is
consumed by a measurement on/after it. A notice is generated at due time, followed
by at most one repeat >=7 days after the first notice. The overdue card remains
afterward. New measurements clear the previous schedule's snooze. Being overdue
never changes the assessment classification.

Apply migration `017_growth_reminders.sql` using the existing migration runner.
The in-app inbox is updated when queried. A daily idempotent worker is also
available from `backend`: `python -m scripts.deliver_growth_reminders`.
There is no FCM/APNs/OS notification delivery in this change; push while the app
is closed requires a separately configured delivery channel. Worker-created
notices are persisted and shown when the app fetches reminders.

Verification:

```powershell
$env:GROWTH_TEST_DATABASE_URL='postgresql://.../tracking_growth_test'
.\.venv\Scripts\python.exe -m pytest backend/tests/test_growth_tracking.py -q
# from mobile
flutter test test/growth_tracking_flow_test.dart test/growth_simple_overview_test.dart test/api_growth_repository_test.dart
```
