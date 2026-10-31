from datetime import date
from app.features.growth.velocity import compare_who_increments


def interval(start, end, gain, period=2):
    return {'intervalId': f'{start}:{end}', 'calculationStatus': 'READY',
        'referenceStatus': 'REFERENCE_MATCHED', 'deltaValue': gain, 'deltaUnit': 'g',
        'from': {'measuredOn': date(2025, start + 1, 1), 'measurementId': str(start)},
        'to': {'measuredOn': date(2025, end + 1, 1), 'measurementId': str(end)},
        'matchedReference': {'intervalMonths': period}}


def test_two_month_gain_comparison_ignores_overlaps_and_input_order():
    rows = [interval(4,6,800), interval(3,5,999), interval(2,4,600)]
    result = compare_who_increments(rows, 2)
    assert result['previousIntervalId'] == '2:4'
    assert result['currentIntervalId'] == '4:6'
    assert result['incrementDifference'] == 200
    assert result['unit'] == 'g'


def test_no_comparison_for_overlapping_gapped_or_other_periods():
    assert compare_who_increments([interval(3,5,500),interval(4,6,800)],2) is None
    assert compare_who_increments([interval(0,2,500),interval(4,6,800)],2) is None
    assert compare_who_increments([interval(2,4,500,3),interval(4,6,800)],2) is None


def test_signed_increment_difference_retains_precision():
    result = compare_who_increments([interval(2,4,-500.49),interval(4,6,-300.47)],2)
    assert result['incrementDifference'] == 200.02
