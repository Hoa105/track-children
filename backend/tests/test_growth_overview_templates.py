from app.features.growth import content


def test_all_weight_overview_templates_have_matching_action_advice():
    assert len(content.OVERVIEWS) == 16
    for (indicator, code), row in content.OVERVIEWS.items():
        result = content.render('ATTAINED', indicator, code)
        assert result['overview']['status'] == 'READY'
        assert result['overview']['text'] == row['overview_template']
        assert result['advice'][0]['status'] == 'READY'
        assert result['advice'][0]['text'].strip()
        assert not result['advice'][0]['text'].startswith(('Kết quả ', 'Chỉ số '))


def test_no_overview_for_unavailable_assessment():
    result = content.render('ASSESSMENT_STATUS', 'ALL_ATTAINED', 'NOT_ASSESSABLE')
    assert result['overview']['status'] == 'NOT_AVAILABLE'
    assert result['overview']['text'] == ''
