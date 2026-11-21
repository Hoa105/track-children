from datetime import date, timedelta
from app.features.notifications.rules import assessment_stage, growth_due


def state():
    return {'age_months':9,'set':{'count':10},'latest_completed':None,
            'milestones':[{'age_months':9,'opens_on':date(2026,9,1),'closes_on':date(2026,12,1)}]}


def test_assessment_before_open_and_next_milestone_are_not_reminded():
    assert assessment_stage(state(),date(2026,8,31)) is None
    assert assessment_stage(state(),date(2026,12,1)) is None


def test_assessment_initial_and_repeat_and_over_thirty_days():
    assert assessment_stage(state(),date(2026,9,1)) == 'open'
    assert assessment_stage(state(),date(2026,9,7)) == 'open'
    assert assessment_stage(state(),date(2026,9,8)) == 'repeat'
    assert assessment_stage(state(),date(2026,11,20)) == 'repeat'


def test_completed_or_unpublished_assessment_is_not_reminded():
    value=state()
    value['latest_completed']={'id':'finished'}
    assert assessment_stage(value,date(2026,9,8)) is None
    value=state()
    value['set']=None
    assert assessment_stage(value,date(2026,9,8)) is None


def test_measurement_reschedules_and_snooze_never_moves_due_earlier():
    last=date(2026,10,1)
    assert growth_due(last,30,{}) == date(2026,10,31)
    assert growth_due(last+timedelta(days=10),30,{}) == date(2026,11,10)
    assert growth_due(last,30,{'snoozed_until':date(2026,10,3)}) == date(2026,10,31)
    assert growth_due(last,30,{'snoozed_until':date(2026,11,20)}) == date(2026,11,20)
    assert growth_due(last,30,{'appointment_on':date(2026,11,21)}) == date(2026,11,21)
