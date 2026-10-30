"""Build the standalone growth contract from the approved local specifications."""
import copy
import csv
import json
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CORE = ROOT / 'docs/core_growth'
OUT = ROOT / 'docs/api/mobile-growth.openapi.json'
STATUS = json.loads((CORE / 'GROWTH-STATUS-CONTRACT.json').read_text(encoding='utf-8'))
with (CORE / 'GROWTH-WHO-CLASSIFICATION-MAP.csv').open(encoding='utf-8', newline='') as f:
    CLASSIFICATIONS = list(csv.DictReader(f))


def ref(name):
    return {'$ref': '#/components/schemas/' + name}


def nullable(schema):
    return {'anyOf': [schema, {'type': 'null'}]}


def enum(values):
    return {'type': 'string', 'enum': list(values)}


def obj(properties, required=None, **extra):
    return {'type': 'object', 'additionalProperties': False, 'properties': properties,
            'required': list(properties) if required is None else required, **extra}


def array(item, **extra):
    return {'type': 'array', 'items': item, **extra}


STRING = {'type': 'string'}
NUMBER = {'type': 'number'}
POSITIVE = {'type': 'number', 'exclusiveMinimum': 0}
INTEGER = {'type': 'integer', 'minimum': 0}
DATE = {'type': 'string', 'format': 'date'}
TIME = {'type': 'string', 'format': 'date-time'}
UUID = {'type': 'string', 'format': 'uuid'}
HASH = {'type': 'string', 'pattern': '^[a-f0-9]{64}$'}
TAG = {'type': 'string', 'pattern': '^W06-[a-f0-9]{24}$', 'maxLength': 30}
METRICS = ['weight', 'height', 'head_circumference', 'bmi']
RAW_METRICS = METRICS[:3]
INDICATORS = [x.lower() for x in STATUS['indicators']]
CODES = sorted({r['classification_code'] for r in CLASSIFICATIONS})
S = {}
for name, key in [('AssessmentStatus', 'assessment_status'), ('AssessmentReason', 'assessment_reason'),
                  ('VelocityCalculationStatus', 'velocity_calculation_status'), ('ReferenceStatus', 'reference_status'),
                  ('ReferenceReason', 'reference_reason'), ('VelocityZScoreStatus', 'velocity_z_score_status'),
                  ('VelocityZScoreReason', 'velocity_z_score_reason'), ('ContentStatus', 'content_status'),
                  ('ReferenceImportStatus', 'reference_import_status')]:
    S[name] = enum(STATUS[key])
S['Metric'] = enum(METRICS)
S['Indicator'] = enum(INDICATORS)
S['ClassificationCode'] = enum(CODES)
S['PointKey'] = obj({'measurementId': UUID, 'pairedMeasurementId': nullable(UUID), 'indicator': ref('Indicator')})
S['Scope'] = obj({'startOn': DATE, 'endBefore': DATE}, description='Effective business-day range [startOn,endBefore), clipped to birth, today and the exclusive 60-calendar-month birthday. endBefore may equal startOn for an empty effective range.')
S['ResponseMeta'] = obj({'schemaVersion': {'const': '1'}, 'snapshotToken': STRING, 'generatedAt': TIME,
                         'engineBundleId': nullable(STRING), 'contentVersion': STRING,
                         'calculationPending': {'type': 'boolean'}}, description='A single consistent snapshot. snapshotToken is opaque, not sortable. engineBundleId=null when the R runtime is unavailable. calculationPending reports unfinished cache misses, not a failed measurement save.')
S['ChildContext'] = obj({'id': UUID, 'fullName': STRING, 'dateOfBirth': DATE,
                         'sex': nullable(enum(['male', 'female'])), 'growthAccess': enum(['view', 'edit'])})
S['ContentBlock'] = obj({'status': ref('ContentStatus'), 'mappingType': enum(STATUS['mapping_scopes']),
                         'code': nullable(enum(sorted(set(CODES + [c for values in STATUS['mapping_codes'].values() for c in values])))),
                         'adviceCode': nullable(STRING), 'text': {'type': 'string', 'minLength': 1}},
                        allOf=[{'if': {'properties': {'status': {'not': {'const': 'READY'}}}},
                                'then': {'properties': {'text': {'const': STATUS['content_fallback']}}}}],
                        description='Only APPROVED templates may produce READY. Failed lookup/review/missing data uses the fixed fallback; never substitute another classification. adviceCode is for advice deduplication, null for comments.')
S['Content'] = obj({'comment': ref('ContentBlock'), 'advice': array(ref('ContentBlock')), 'ageContext': array(ref('ContentBlock'))})
assessment_props = {'indicator': ref('Indicator'), 'measurementId': UUID, 'pairedMeasurementId': nullable(UUID),
                    'status': ref('AssessmentStatus'), 'reason': nullable(ref('AssessmentReason')),
                    'zScore': nullable(NUMBER), 'classificationCode': nullable(ref('ClassificationCode')),
                    'zScorePrecision': {'const': 2}, 'precisionSource': {'const': 'anthro_public_output'},
                    'sourceStandard': {'const': 'WHO-2006'}, 'cacheTag': nullable(TAG), 'content': ref('Content')}
conditions = []
for state, reasons in STATUS['assessment_reasons_by_status'].items():
    fields = {'reason': enum(reasons) if reasons else {'type': 'null'}}
    if state == 'READY':
        fields['zScore'] = NUMBER
    else:
        fields.update(zScore={'type': 'null'}, classificationCode={'type': 'null'}, cacheTag={'type': 'null'})
    conditions.append({'if': {'properties': {'status': {'const': state}}}, 'then': {'properties': fields}})
for indicator in INDICATORS:
    codes = [r['classification_code'] for r in CLASSIFICATIONS if r['indicator'].lower() == indicator]
    conditions.append({'if': {'properties': {'indicator': {'const': indicator}}},
                       'then': {'properties': {'classificationCode': nullable(enum(codes)),
                                              'pairedMeasurementId': nullable(UUID) if indicator in ('bmifa', 'wfl', 'wfh') else {'type': 'null'}}}})
conditions.append({'if': {'properties': {'indicator': enum(['bmifa','wfl','wfh']), 'status': {'const':'READY'}}},
                   'then': {'properties': {'pairedMeasurementId':UUID}}})
conditions.append({'if': {'properties': {'cacheTag': {'type': 'string'}}},
                   'then': {'properties': {'status': {'const': 'READY'}, 'classificationCode': ref('ClassificationCode')}}})
S['IndicatorAssessment'] = obj(assessment_props, allOf=conditions,
    description='Z is the unchanged public anthro 1.1.0 output (already rounded to 2 decimals). READY may have null classification when its mapping is not approved; then cacheTag=null. A flag/policy failure only removes the affected indicators, not other valid indicators on the day.')
S['Normalization'] = obj({'status': enum(['READY', 'NOT_ASSESSABLE', 'RECHECK_DATA', 'NOT_APPLICABLE']),
                           'reason': nullable(ref('AssessmentReason')), 'basis': nullable(enum(['recumbent_length', 'standing_height'])),
                           'normalizedLenheiCm': nullable(POSITIVE), 'adjustmentCm': nullable(enum_number := {'type': 'number', 'enum': [-0.7, 0, 0.7]})},
                          description='Normalized by the 731-day anthro boundary, not calendar-month display labels or raw cmeasure. c9mo_flag=1 disallows height-based assessment even if R returns finite numbers.',
                          allOf=[{'if': {'properties': {'status': {'const': 'READY'}}},
                                  'then': {'properties': {'reason': {'type': 'null'}, 'basis': enum(['recumbent_length', 'standing_height']), 'normalizedLenheiCm': POSITIVE, 'adjustmentCm': enum_number}}}])
S['Measurement'] = obj({'id': UUID, 'metric': enum(RAW_METRICS), 'value': {'type': 'number', 'exclusiveMinimum': 0, 'maximum': 99999.99, 'multipleOf': 0.01},
                        'unit': enum(['kg', 'cm']), 'measuredOn': DATE, 'measuredAt': TIME, 'ageDays': INTEGER,
                        'measurePosition': nullable(enum(['lying', 'standing'])), 'note': nullable({'type': 'string', 'maxLength': 2000}),
                        'createdAt': TIME, 'updatedAt': TIME}, allOf=[
    {'if': {'properties': {'metric': {'const': 'weight'}}}, 'then': {'properties': {'unit': {'const': 'kg'}, 'measurePosition': {'type': 'null'}}}},
    {'if': {'properties': {'metric': {'const': 'height'}}}, 'then': {'properties': {'unit': {'const': 'cm'}, 'measurePosition': enum(['lying', 'standing'])}}},
    {'if': {'properties': {'metric': {'const': 'head_circumference'}}}, 'then': {'properties': {'unit': {'const': 'cm'}, 'measurePosition': {'type': 'null'}}}}
], description='Raw active measurement only. measuredOn is Asia/Ho_Chi_Minh business date. Deleted rows are excluded. IDs, not names/indexes, identify points.')
S['RawValues'] = obj({'weightKg': nullable(POSITIVE), 'heightCm': nullable(POSITIVE), 'headCircumferenceCm': nullable(POSITIVE), 'measurePosition': nullable(enum(['lying', 'standing']))})
sample_props = {'measurementId': UUID, 'pairedMeasurementId': nullable(UUID), 'measuredOn': DATE, 'ageDays': INTEGER,
                'ageLabel': STRING, 'value': POSITIVE, 'unit': enum(['kg', 'cm', 'kg/m2']), 'raw': ref('RawValues'),
                'normalization': nullable(ref('Normalization')), 'assessments': array(ref('IndicatorAssessment'), maxItems=6)}
S['MetricSample'] = obj(sample_props, description='Value/normalization calculated by backend. BMI and weight-for-size use the same active-day weight/height pair. No client-side re-pairing or raw-height BMI. A sample may have unavailable assessments.')
S['ChartPoint'] = obj({**sample_props, 'x': NUMBER, 'y': NUMBER, 'segmentId': STRING, 'assessment': ref('IndicatorAssessment')},
                      description='x/y must equal the selected chart units and normalization. measurementId+pairedMeasurementId+indicator is the stable selection key; duplicate x at different dates must remain distinct. assessment is the entry for this chart in assessments.')
S['OmittedPoint'] = obj({'measurementId': UUID, 'pairedMeasurementId': nullable(UUID), 'measuredOn': DATE,
                         'raw': ref('RawValues'), 'reason': ref('AssessmentReason')})
S['Axis'] = obj({'type': enum(['age_days', 'length_cm', 'height_cm', 'weight', 'length', 'head_circumference', 'bmi', 'interval_end_date']),
                 'unit': enum(['days', 'date', 'cm', 'kg', 'kg/m2', 'g', 'g/month', 'cm/month']),
                 'displayUnit': STRING, 'min': nullable(NUMBER), 'max': nullable(NUMBER)})
S['ReferenceSource'] = obj({'datasetId': STRING, 'sha256': HASH, 'sourceUrl': {'type': 'string', 'format': 'uri'},
                            'version': STRING, 'retrievedOn': DATE, 'sex': enum(['male', 'female']),
                            'standard': STRING, 'unit': enum(['kg', 'cm', 'kg/m2', 'g']),
                            'xType': enum(['age_days', 'length_cm', 'height_cm', 'interval']), 'xMin': NUMBER, 'xMax': NUMBER})
S['Curve'] = obj({'sd': {'type': 'integer', 'enum': [-3, -2, -1, 0, 1, 2, 3]},
                  'points': array(obj({'x': NUMBER, 'y': NUMBER}))})
S['ReferenceSegment'] = obj({'id': STRING, 'datasetId': STRING, 'basis': nullable(enum(['recumbent_length', 'standing_height'])),
                             'xMin': NUMBER, 'xMax': NUMBER, 'curves': array(ref('Curve'), maxItems=7)},
                            description='LHFA/BMIFA split at 731 days. Never join curves/child series across the normalization boundary. Draw-only interpolation within a curve/segment is not an assessment or exact SD evidence.')
S['ChartReference'] = obj({'importStatus': nullable(ref('ReferenceImportStatus')), 'reason': nullable(ref('ReferenceReason')),
                           'standard': nullable(STRING), 'sources': array(ref('ReferenceSource')), 'segments': array(ref('ReferenceSegment'))},
                          allOf=[{'if': {'properties': {'importStatus': {'not': {'const': 'VERIFIED'}}}},
                                  'then': {'properties': {'segments': {'maxItems': 0}}}}],
                          description='Missing file: importStatus=null/reason=MISSING_REFERENCE_FILE, no curves. Non-VERIFIED imports never supply overlays. Numeric R assessments can remain READY independently.')
S['Warning'] = obj({'scope': enum(['assessment', 'reference', 'content', 'engine']), 'status': STRING, 'reason': nullable(STRING)},
                   description='status/reason must belong to the named namespace in the status contract; no undocumented widget-only codes.')
S['Evidence'] = obj({'indicator': ref('Indicator'), 'measurementId': UUID, 'pairedMeasurementId': nullable(UUID),
                     'datasetId': nullable(STRING), 'referenceVersion': nullable(STRING), 'x': NUMBER,
                     'sdValues': array(obj({'sd': {'type': 'integer', 'enum': [-3,-2,-1,0,1,2,3]}, 'value': NUMBER})),
                     'available': {'type': 'boolean'}, 'reason': nullable(enum(['MISSING_REFERENCE_FILE', 'REFERENCE_NOT_VERIFIED', 'NO_MATCHING_AGE', 'NO_MATCHING_INTERVAL']))},
                    description='Exact official SD values at this x/basis/version only. Do not present interpolated display curves as exact reference evidence. Empty evidence does not invalidate a public R Z-score.')
S['Chart'] = obj({'chartId': enum(['WFA_AGE', 'LHFA_AGE', 'HCFA_AGE', 'BMIFA_AGE', 'WFL_LENGTH', 'WFH_HEIGHT']),
                  'indicator': ref('Indicator'), 'xAxis': ref('Axis'), 'yAxis': ref('Axis'), 'reference': ref('ChartReference'),
                  'childPoints': array(ref('ChartPoint')), 'omittedPoints': array(ref('OmittedPoint')),
                  'selectedPointKey': nullable(ref('PointKey')), 'evidence': array(ref('Evidence')), 'warnings': array(ref('Warning'))},
                 description='Six attained-growth charts; WFL/WFH are scatter (x=cm,y=kg), not age plots. No synthetic y=0 WHO coordinates. Filter changes viewport, not classifications.')
S['VelocityCapability'] = obj({'metric': enum(RAW_METRICS), 'actualSupported': {'const': True},
                               'whoIntervalMonths': array({'type': 'integer', 'enum': [1,2,3,4,6]}, uniqueItems=True),
                               'referenceImportStatus': nullable(ref('ReferenceImportStatus'))},
                              description='Supported periods, not a promise of a match for every age. Weight 1-month and head 2/3-month tables end at 12 months. Length/head do not support period 1. Product WHO comparison requires end age below 24 calendar months.')
S['Capabilities'] = obj({'metrics': array(ref('Metric'), uniqueItems=True), 'velocity': array(ref('VelocityCapability'), maxItems=3),
                         'bmiVelocitySupported': {'const': False}, 'whoVelocityEndAgeMonthsExclusive': {'const': 24}, 'maxAgeMonthsExclusive': {'const': 60}})
S['OverviewCard'] = obj({'metric': ref('Metric'), 'latest': nullable(ref('MetricSample')), 'sparkline': array(ref('MetricSample'))},
                        description='latest uses all active history independent of the sparkline date filter. No average Z-score.')
common = {'meta': ref('ResponseMeta'), 'child': ref('ChildContext'), 'scope': ref('Scope')}
S['OverviewResponse'] = obj({**common, 'cards': array(ref('OverviewCard'), minItems=4, maxItems=4,
    allOf=[{'contains':{'properties':{'metric':{'const':m}},'required':['metric']},'minContains':1,'maxContains':1} for m in METRICS]), 'capabilities': ref('Capabilities')},
                           description='Exactly one card for each metric; absent values are latest=null and sparkline=[].')
S['MetricDetailResponse'] = obj({**common, 'metric': ref('Metric'), 'measurements': array(ref('Measurement')),
                                 'samples': array(ref('MetricSample')), 'charts': array(ref('Chart'), minItems=1, maxItems=2),
                                 'selectedPointKey': nullable(ref('PointKey')), 'capabilities': ref('Capabilities')},
                                description='Full data in the effective date range (no hidden pagination). BMI includes its source raw measurements. Weight returns WFA plus the requested/default WFL or WFH chart, even empty. Other metrics return one age chart. Per-chart datasets and source metadata must share this snapshot.')
S['DayResponse'] = obj({'meta': ref('ResponseMeta'), 'child': ref('ChildContext'), 'measuredOn': DATE,
                       'measurements': array(ref('Measurement'), maxItems=3), 'bmi': nullable(ref('MetricSample')),
                       'assessments': array(ref('IndicatorAssessment'), maxItems=5)},
                      description='An empty day is 200 with measurements=[], bmi=null, assessments=[]. No fake pending evaluation without a primary measurement. At most WFA/LHFA/HCFA/BMIFA plus one WFL/H.')
S['SaveDayRequest'] = obj({'weightKg': {'type': 'number', 'exclusiveMinimum': 0, 'maximum': 99999.99, 'multipleOf': 0.01},
                           'height': obj({'value': {'type': 'number', 'exclusiveMinimum': 0, 'maximum': 99999.99, 'multipleOf': 0.01}, 'measurePosition': enum(['lying', 'standing'])}),
                           'headCircumferenceCm': {'type': 'number', 'exclusiveMinimum': 0, 'maximum': 99999.99, 'multipleOf': 0.01},
                           'measuredAt': TIME, 'note': nullable({'type': 'string', 'maxLength': 2000})},
                          required=[], anyOf=[{'required': [key]} for key in ['weightKg', 'height', 'headCircumferenceCm']],
                          description='Partial-day upsert. At least one non-null metric. kg/cm only; no manual age/BMI/Z/unit/IDs. note absent preserves notes, null clears; applies only to supplied metrics. measuredAt if supplied must have a timezone, match path business day and not be in the future. If omitted preserve existing row timestamp, or use local midnight for a new row as a date-only convention, not recovered actual time.')
S['SaveDayResponse'] = obj({'measurementSaved': {'const': True}, 'changedMetrics': array(enum(RAW_METRICS), uniqueItems=True), 'day': ref('DayResponse')},
                          description='200 even when R is unavailable after commit. Repeat same values keeps active IDs and may yield changedMetrics=[]. Never report a committed measurement as an unsuccessful save because assessment failed.')
S['VelocityEndpoint'] = obj({'measurementId': UUID, 'measuredOn': DATE, 'ageDays': INTEGER, 'rawValue': POSITIVE,
                            'comparisonValue': nullable(POSITIVE), 'normalization': nullable(ref('Normalization'))})
S['MatchedVelocityReference'] = obj({'source': ref('ReferenceSource'), 'intervalLabel': STRING,
                                     'tableIntervalMonths': {'type': 'integer', 'enum': [1,2,3,4,6]}, 'intervalMonths': nullable({'type': 'integer', 'minimum': 1}),
                                     'startAgeValue': INTEGER, 'startAgeUnit': enum(['weeks', 'months']), 'endAgeValue': INTEGER, 'endAgeUnit': enum(['weeks', 'months']),
                                     'sdValues': array(obj({'sd': {'type': 'integer', 'enum': [-3,-2,-1,0,1,2,3]}, 'value': NUMBER}), minItems=7, maxItems=7)},
                                    description='Full-interval increments in g or cm, including negative/zero published values and ties. intervalMonths=null for mixed week/month rows. Only verified source and exact calendar/week anchors; no interpolation or division into monthly rates.')
vprops = {'intervalId': STRING, 'from': ref('VelocityEndpoint'), 'to': ref('VelocityEndpoint'), 'elapsedDays': {'type': 'integer'},
          'calculationStatus': ref('VelocityCalculationStatus'), 'deltaValue': nullable(NUMBER), 'deltaUnit': enum(['g','cm']),
          'ratePerMonth': nullable(NUMBER), 'rateUnit': enum(['g/month','cm/month']),
          'referenceStatus': ref('ReferenceStatus'), 'referenceReason': nullable(ref('ReferenceReason')),
          'matchedReference': nullable(ref('MatchedVelocityReference')), 'zScoreStatus': ref('VelocityZScoreStatus'),
          'zScoreReason': nullable(ref('VelocityZScoreReason')), 'zScore': nullable(NUMBER),
          'content': ref('Content'), 'zScoreContent': nullable(ref('Content'))}
vconditions = [{'if': {'properties': {'calculationStatus': {'const': 'READY'}}},
                'then': {'properties': {'elapsedDays': {'type':'integer','minimum':1}, 'deltaValue':NUMBER,'ratePerMonth':NUMBER,'referenceStatus':{'not':{'const':'NOT_REQUESTED'}}}},
                'else': {'properties': {'deltaValue':{'type':'null'},'ratePerMonth':{'type':'null'},'referenceStatus':{'const':'NOT_REQUESTED'},'zScoreStatus':{'const':'NOT_REQUESTED'}}}}]
for state, reasons in STATUS['reference_reasons_by_status'].items():
    fields = {'referenceReason': enum(reasons) if reasons else {'type': 'null'}}
    if state == 'REFERENCE_MATCHED':
        fields.update(matchedReference=ref('MatchedVelocityReference'), zScoreStatus=enum(['READY','UNAVAILABLE']))
    else:
        fields.update(matchedReference={'type':'null'}, zScoreStatus={'const':'NOT_REQUESTED'}, zScoreContent={'type':'null'})
    vconditions.append({'if': {'properties': {'referenceStatus': {'const':state}}}, 'then': {'properties':fields}})
for state in STATUS['velocity_z_score_status']:
    fields = {'zScore': NUMBER if state == 'READY' else {'type':'null'},
              'zScoreReason': ref('VelocityZScoreReason') if state == 'UNAVAILABLE' else {'type':'null'},
              'zScoreContent': ref('Content') if state == 'UNAVAILABLE' else {'type':'null'}}
    vconditions.append({'if': {'properties': {'zScoreStatus': {'const':state}}}, 'then': {'properties':fields}})
S['VelocityInterval'] = obj(vprops, allOf=vconditions, description='Actual rate = full-interval delta / elapsedDays * 30.4375. Do not round before calculation. Negative and zero increments remain valid numeric observations. REFERENCE_MATCHED is not a healthy/unhealthy classification; Z may still be unavailable.')
S['VelocityTrend'] = obj({'code': enum(STATUS['mapping_codes']['VELOCITY_TREND']), 'previousIntervalId': STRING, 'currentIntervalId': STRING,
                          'previousRatePerMonth':NUMBER, 'currentRatePerMonth':NUMBER, 'rateDifference':{'type':'number','minimum':0},
                          'rateUnit':enum(['g/month','cm/month']), 'content':ref('Content')},
                         description='Only two consecutive non-overlapping actual intervals with same basis/units. Compare unrounded actual rates; UNCHANGED means exact equality, no implicit epsilon. rateDifference is magnitude, not signed change.')
S['VelocityResponse'] = obj({**common, 'metric':enum(RAW_METRICS),'mode':enum(['actual','who']),
                             'intervalMonths':nullable({'type':'integer','enum':[1,2,3,4,6]}),
                             'calculationStatus':ref('VelocityCalculationStatus'),
                             'referenceStatus':ref('ReferenceStatus'),'referenceReason':nullable(ref('ReferenceReason')),
                             'actualIntervals':array(ref('VelocityInterval')), 'whoIntervals':array(ref('VelocityInterval')),
                             'selectedActualIntervalId':nullable(STRING),'selectedWhoIntervalId':nullable(STRING),
                             'trend':nullable(ref('VelocityTrend')), 'content':ref('Content'), 'capabilities':ref('Capabilities')},
                            allOf=[{'if':{'properties':{'mode':{'const':'actual'}}},
                                    'then':{'properties':{'intervalMonths':{'type':'null'},'whoIntervals':{'maxItems':0},'selectedWhoIntervalId':{'type':'null'}}},
                                    'else':{'properties':{'intervalMonths':{'type':'integer','enum':[1,2,3,4,6]}}}},
                                   {'if':{'properties':{'calculationStatus':{'not':{'const':'READY'}}}},
                                    'then':{'properties':{'referenceStatus':{'const':'NOT_REQUESTED'},'referenceReason':{'type':'null'},'trend':{'type':'null'}}}}],
                            description='Actual list is built from consecutive active readings before filtering by interval end date. WHO list is separate and may use different pairs or overlap. Selecting a WHO pair never changes actual latest rate. No exact match is 200 with reason, not a fabricated WHO Z-score.')
S['ErrorResponse'] = obj({'error':obj({'code':enum(sorted(set(STATUS['request_error_codes'] + ['VALIDATION_ERROR','RESOURCE_NOT_FOUND','DATABASE_UNAVAILABLE','AUTH_NOT_CONFIGURED','ACCESS_TOKEN_REQUIRED','ACCESS_TOKEN_INVALID','ACCESS_TOKEN_EXPIRED','SESSION_REVOKED','SESSION_EXPIRED','ACCOUNT_UNAVAILABLE']))),
                                     'message':STRING,'fields':{'type':'object','additionalProperties':{'type':'string'}},
                                     'details':{'type':'object','additionalProperties':True}})}, description='Transport/request failures only; follows auth error envelope. Engine/reference/content failures normally stay in successful data responses.')


CHILD='00000000-0000-4000-8000-000000000101'
MID='00000000-0000-4000-8000-000000000201'
HID='00000000-0000-4000-8000-000000000202'
META={'schemaVersion':'1','snapshotToken':'synthetic-example-snapshot','generatedAt':'2026-10-29T03:00:00Z','engineBundleId':None,'contentVersion':'mapping-v2.1-example','calculationPending':False}
CHILD_DATA={'id':CHILD,'fullName':'Bé minh họa','dateOfBirth':'2025-01-01','sex':'female','growthAccess':'edit'}
SCOPE={'startOn':'2025-01-01','endBefore':'2026-10-30'}
CAP={'metrics':METRICS,'velocity':[{'metric':m,'actualSupported':True,'whoIntervalMonths':([1,2,3,4,6] if m=='weight' else [2,3,4,6]),'referenceImportStatus':'LOCAL_STRUCTURE_CHECKED'} for m in RAW_METRICS], 'bmiVelocitySupported':False,'whoVelocityEndAgeMonthsExclusive':24,'maxAgeMonthsExclusive':60}


def content(kind, code):
    block={'status':'MAPPING_NOT_APPROVED','mappingType':kind,'code':code,'adviceCode':None,'text':STATUS['content_fallback']}
    return {'comment':block,'advice':[],'ageContext':[]}


def assessment(state='CALCULATION_UNAVAILABLE', reason='R_EXECUTION_FAILED', indicator='wfa'):
    return {'indicator':indicator,'measurementId':MID,'pairedMeasurementId':HID if indicator in ('bmifa','wfl','wfh') else None,
            'status':state,'reason':reason,'zScore':0.49 if state=='READY' else None,'classificationCode':None,
            'zScorePrecision':2,'precisionSource':'anthro_public_output','sourceStandard':'WHO-2006','cacheTag':None,
            'content':content('ATTAINED' if state=='READY' else 'ASSESSMENT_STATUS','WITHIN_RANGE' if state=='READY' else state)}


MEAS={'id':MID,'metric':'weight','value':9.5,'unit':'kg','measuredOn':'2026-01-01','measuredAt':'2026-01-01T03:00:00Z','ageDays':365,'measurePosition':None,'note':None,'createdAt':'2026-01-01T03:00:00Z','updatedAt':'2026-01-01T03:00:00Z'}
SAMPLE={'measurementId':MID,'pairedMeasurementId':None,'measuredOn':'2026-01-01','ageDays':365,'ageLabel':'12 tháng','value':9.5,'unit':'kg',
        'raw':{'weightKg':9.5,'heightCm':None,'headCircumferenceCm':None,'measurePosition':None},'normalization':None,'assessments':[assessment()]}
EMPTY_OVERVIEW={**copy.deepcopy(common_values := {'meta':META,'child':CHILD_DATA,'scope':SCOPE}), 'cards':[{'metric':m,'latest':None,'sparkline':[]} for m in METRICS],'capabilities':CAP}
OVERVIEW=copy.deepcopy(EMPTY_OVERVIEW)
OVERVIEW['cards'][0].update(latest=SAMPLE,sparkline=[SAMPLE])
EMPTY_DAY={'meta':META,'child':CHILD_DATA,'measuredOn':'2026-01-01','measurements':[],'bmi':None,'assessments':[]}
DAY={**EMPTY_DAY,'measurements':[MEAS],'assessments':[assessment()]}
REF_MISSING={'importStatus':None,'reason':'MISSING_REFERENCE_FILE','standard':'WHO-2006','sources':[],'segments':[]}


def chart(indicator='wfa', points=None):
    length=indicator=='wfl'
    return {'chartId':'WFL_LENGTH' if length else 'WFA_AGE','indicator':indicator,
            'xAxis':{'type':'length_cm' if length else 'age_days','unit':'cm' if length else 'days','displayUnit':'cm' if length else 'calendar_months','min':45 if length else 0,'max':110 if length else 1826},
            'yAxis':{'type':'weight','unit':'kg','displayUnit':'kg','min':None,'max':None},'reference':REF_MISSING,
            'childPoints':points or [],'omittedPoints':[],'selectedPointKey':None,'evidence':[],
            'warnings':[{'scope':'reference','status':'REFERENCE_UNAVAILABLE','reason':'MISSING_REFERENCE_FILE'}]}


POINT={**SAMPLE,'x':365,'y':9.5,'segmentId':'wfa','assessment':assessment()}
DETAIL={**common_values,'metric':'weight','measurements':[MEAS],'samples':[SAMPLE],'charts':[chart(points=[POINT]),chart('wfl')],
        'selectedPointKey':{'measurementId':MID,'pairedMeasurementId':None,'indicator':'wfa'},'capabilities':CAP}
DETAIL['charts'][0]['selectedPointKey']=DETAIL['selectedPointKey']
EMPTY_VELOCITY={**common_values,'metric':'weight','mode':'actual','intervalMonths':None,'calculationStatus':'INSUFFICIENT_MEASUREMENTS',
                'referenceStatus':'NOT_REQUESTED','referenceReason':None,'actualIntervals':[],'whoIntervals':[],
                'selectedActualIntervalId':None,'selectedWhoIntervalId':None,'trend':None,'content':content('VELOCITY','INSUFFICIENT_MEASUREMENTS'),'capabilities':CAP}
ERROR={'error':{'code':'VALIDATION_ERROR','message':'VALIDATION_ERROR','fields':{'height.measurePosition':'Required for height'},'details':{}}}
EXAMPLES={'OverviewEmpty':EMPTY_OVERVIEW,'OverviewEngineUnavailable':OVERVIEW,'DayEmpty':EMPTY_DAY,'DayEngineUnavailable':DAY,
          'DetailReferenceUnavailable':DETAIL,'VelocityInsufficient':EMPTY_VELOCITY,
          'SaveAssessmentUnavailable':{'measurementSaved':True,'changedMetrics':['weight'],'day':DAY},
          'RequestWeight':{'weightKg':9.5},'RequestPair':{'weightKg':9.5,'height':{'value':75,'measurePosition':'lying'},'note':None},'ValidationError':ERROR}
VIEW_ONLY=copy.deepcopy(OVERVIEW)
VIEW_ONLY['child']['growthAccess']='view'
EXAMPLES['OverviewViewOnly']=VIEW_ONLY
MISSING_PAIR=copy.deepcopy(DAY)
MISSING_PAIR['meta']['engineBundleId']='synthetic-local-anthro-1.1.0'
MISSING_PAIR['assessments']=[assessment('READY',None)]
for indicator in ('bmifa','wfl'):
    missing=assessment('NOT_ASSESSABLE','MISSING_PAIRED_MEASUREMENT',indicator)
    missing['pairedMeasurementId']=None
    MISSING_PAIR['assessments'].append(missing)
EXAMPLES['DayMissingPair']=MISSING_PAIR
FLAGGED=copy.deepcopy(DAY)
FLAGGED['meta']['engineBundleId']='synthetic-local-anthro-1.1.0'
FLAGGED['measurements'][0]['value']=40
FLAGGED['assessments']=[assessment('RECHECK_DATA','WHO_FLAGGED')]
EXAMPLES['DayWhoFlagged']=FLAGGED
INTERVAL={'intervalId':'synthetic-actual-interval','from':{'measurementId':MID,'measuredOn':'2026-08-01','ageDays':(date(2026,8,1)-date(2025,1,1)).days,'rawValue':9.0,'comparisonValue':9.0,'normalization':None},
          'to':{'measurementId':HID,'measuredOn':'2026-08-31','ageDays':(date(2026,8,31)-date(2025,1,1)).days,'rawValue':9.3,'comparisonValue':9.3,'normalization':None},
          'elapsedDays':30,'calculationStatus':'READY','deltaValue':300,'deltaUnit':'g','ratePerMonth':304.375,'rateUnit':'g/month',
          'referenceStatus':'NO_EXACT_REFERENCE','referenceReason':'NO_MATCHING_INTERVAL','matchedReference':None,
          'zScoreStatus':'NOT_REQUESTED','zScoreReason':None,'zScore':None,'content':content('VELOCITY','ACTUAL_ONLY'),'zScoreContent':None}
ACTUAL=copy.deepcopy(EMPTY_VELOCITY)
ACTUAL.update(calculationStatus='READY',referenceStatus='NO_EXACT_REFERENCE',referenceReason='NO_MATCHING_INTERVAL',
              actualIntervals=[INTERVAL],selectedActualIntervalId=INTERVAL['intervalId'],content=content('VELOCITY','ACTUAL_ONLY'))
EXAMPLES['VelocityActualOnly']=ACTUAL
UNVERIFIED=copy.deepcopy(ACTUAL)
UNVERIFIED.update(mode='who',intervalMonths=2,referenceStatus='REFERENCE_UNVERIFIED',referenceReason='REFERENCE_NOT_VERIFIED',content=content('VELOCITY','REFERENCE_UNVERIFIED'))
UNVERIFIED['actualIntervals'][0].update(referenceStatus='REFERENCE_UNVERIFIED',referenceReason='REFERENCE_NOT_VERIFIED',content=content('VELOCITY','REFERENCE_UNVERIFIED'))
EXAMPLES['VelocityReferenceUnverified']=UNVERIFIED


def ex(name):
    return {'$ref':'#/components/examples/'+name}


HEADERS={'Cache-Control':{'description':'All child-specific responses are private and not stored by shared caches.','schema':{'type':'string','const':'no-store'}}}


def response(schema, description, names=()):
    return {'description':description,'headers':copy.deepcopy(HEADERS),'content':{'application/json':{'schema':ref(schema),'examples':{n:ex(n) for n in names}}}}


PARAMS={
 'ChildId':{'name':'childId','in':'path','required':True,'schema':UUID,'description':'Real authorized child UUID, never a display name or local demo ID.'},
 'Metric':{'name':'metric','in':'path','required':True,'schema':ref('Metric')},
 'VelocityMetric':{'name':'metric','in':'path','required':True,'schema':enum(RAW_METRICS),'description':'BMI velocity is not a supported operation; bmi is a 422 INVALID_METRIC request.'},
 'MeasuredOn':{'name':'measuredOn','in':'path','required':True,'schema':DATE,'description':'Asia/Ho_Chi_Minh business date. Cannot precede birth, be future, or be on/after the 60-month birthday.'},
 'MeasurementId':{'name':'measurementId','in':'path','required':True,'schema':UUID},
 'StartOn':{'name':'startOn','in':'query','schema':DATE,'description':'Inclusive date. Default birth date; effective range clipped to product scope. A supplied startOn must be before a supplied endBefore.'},
 'EndBefore':{'name':'endBefore','in':'query','schema':DATE,'description':'Exclusive date. Default min(tomorrow business date,60-month birthday). Clipping can produce an empty effective range.'},
 'SelectedMeasurementId':{'name':'selectedMeasurementId','in':'query','schema':UUID,'description':'Optional primary ID within the effective range. Belongs to this child and requested metric (weight for BMI). Missing/deleted/other-child ID is 404; an authorized ID outside this metric/range is 422. Default newest visible point.'},
 'WeightForSizeIndicator':{'name':'weightForSizeIndicator','in':'query','schema':enum(['wfl','wfh']),'description':'Only for metric=weight. Default branch of newest visible same-day pair by age_days; if none, branch by child current age. Explicit branch returns only eligible pairs for that branch, never converts WFL into WFH to force a match.'},
 'StatureView':{'name':'statureView','in':'query','schema':enum(['radius5','radius10','all'])|{'default':'radius5'},'description':'Only weight detail secondary scatter. Anchor is newest eligible pair in branch; clip reference viewport to the official cm domain. Does not change assessment or discard primary WFA history.'},
 'VelocityMode':{'name':'mode','in':'query','schema':enum(['actual','who'])|{'default':'actual'}},
 'IntervalMonths':{'name':'intervalMonths','in':'query','schema':{'type':'integer','enum':[1,2,3,4,6]},'description':'Required in who mode, forbidden in actual mode. Unsupported metric/period combination is 422 INVALID_VALUE; a supported period with no matching pair is 200 NO_EXACT_REFERENCE. Head/length period 1 unsupported; weight period 1 preserves its first mixed week/month rows.'}
}


def parameters(*names):
    return [{'$ref':'#/components/parameters/'+name} for name in names]


def operation(opid, summary, description, schema, examples, params):
    return {'operationId':opid,'tags':['Mobile Growth'],'summary':summary,'description':description,
            'parameters':parameters(*params),'responses':{'200':response(schema,'Success; inspect per-block computation/reference/content statuses.',examples),
             **{str(code):{'$ref':'#/components/responses/'+name} for code,name in [(401,'Unauthorized'),(403,'Forbidden'),(404,'NotFound'),(422,'ValidationError'),(503,'DatabaseUnavailable')]}}}


budget='Read computation has a cumulative 15-second R execution budget plus a bounded 2-second queue wait. Process at most 128 days per R batch, prioritize selected/latest days, and mark remaining misses PENDING_CALCULATION. Release DB locks during R; bound total HTTP work to 20 seconds, with explicit client timeout at least 30 seconds. No unlimited 5-year synchronous recomputation. Repeated GETs may warm reproducible cache, never mutate raw measurements.'
paths={}
base='/children/{childId}/growth'
paths[base]={'get':operation('getGrowthOverview','Tổng quan bốn nhóm tăng trưởng',
    'Authorized snapshot of child context and exactly four cards. latest is independent of date filters; sparkline uses the effective range. Authentication uses the current mobile session, no growth-specific login. '+budget,
    'OverviewResponse',['OverviewEmpty','OverviewEngineUnavailable','OverviewViewOnly'],['ChildId','StartOn','EndBefore'])}
paths[base+'/metrics/{metric}']={'get':operation('getGrowthMetricDetail','Chi tiết, lịch sử, biểu đồ và đánh giá',
    'All active readings/samples in range, no pagination that silently truncates chart history. Same-day pairs only. For weight, primary WFA plus a WFL/WFH scatter; other metrics return one age chart. Filters never change Z/classification. Seven SD curves only from verified data, segmented at day 731 where applicable. Exact evidence may be empty even if R assessment is valid. selected point assessment/content matches its IDs and snapshot. Missing paired data keeps raw history, bmi samples absent, and an explicit NOT_ASSESSABLE/MISSING_PAIRED_MEASUREMENT for affected eligible primary IDs. '+budget,
    'MetricDetailResponse',['DetailReferenceUnavailable'],['ChildId','Metric','StartOn','EndBefore','SelectedMeasurementId','WeightForSizeIndicator','StatureView'])}
paths[base+'/metrics/{metric}/velocity']={'get':operation('getGrowthVelocity','Tốc độ thực tế và đối chiếu WHO theo kỳ',
    'Actual intervals use consecutive readings from full active history before filtering end dates; keep predecessor outside viewport. Actual unit g/month or cm/month uses 30.4375 days. Each actual pair may be annotated against the unique exact source row for its own dates, without changing the pair or drawing a WHO overlay in actual mode. WHO intervals have separate IDs, full-interval units g/cm, exact DOB calendar-month or 28-day anchors, correct sex/age/period. No rate overlay with interval gains. who mode requires intervalMonths; actual mode forbids it and returns whoIntervals=[]. With fewer than two valid readings return INSUFFICIENT_MEASUREMENTS/NOT_REQUESTED and no bars. With valid actual rate but no exact pair, return READY/NO_EXACT_REFERENCE. Missing/unverified sources and >=24-month end ages use their distinct statuses. Never issue REFERENCE_LOW/HIGH/MIDDLE/EXTREME or a velocity diagnosis. '+budget,
    'VelocityResponse',['VelocityInsufficient','VelocityActualOnly','VelocityReferenceUnverified'],['ChildId','VelocityMetric','StartOn','EndBefore','VelocityMode','IntervalMonths'])}
paths[base+'/days/{measuredOn}']={
 'get':operation('getGrowthDay','Đọc các số đo và cặp BMI theo ngày',
    'Authorized daily form snapshot. No measurements is 200, not 404. Reconstruct derived BMI from active same-day pair using engine normalization; no manual BMI. '+budget,
    'DayResponse',['DayEmpty','DayEngineUnavailable','DayMissingPair','DayWhoFlagged'],['ChildId','MeasuredOn']),
 'put':operation('upsertGrowthDay','Lưu hoặc cập nhật một phần số đo trong ngày',
    'Requires edit. Atomically upsert only supplied metrics, partial unique active(child,metric,measured_on). Repeating payload preserves active IDs; omitted fields stay unchanged. Null metrics rejected; use DELETE for removal. Validate before commit. Parent child row lock serializes writers; invalidate dependent evaluations in same transaction. Run R outside transaction, check input fingerprint under lock before publishing. Once saved, return 200 measurementSaved=true even if R times out; never resurrect stale cache or ask client to submit again. Date changes are not supported by this PUT: it writes the path day, does not move an existing ID. Existing date correction requires a separately designed move operation, not automatic delete/reinsert. '+budget,
    'SaveDayResponse',['SaveAssessmentUnavailable'],['ChildId','MeasuredOn'])}
paths[base+'/days/{measuredOn}']['put']['requestBody']={'required':True,'content':{'application/json':{'schema':ref('SaveDayRequest'),'examples':{'weightOnly':ex('RequestWeight'),'sameDayPair':ex('RequestPair')}}}}
paths[base+'/measurements/{measurementId}']={'delete':{
 'operationId':'deleteGrowthMeasurement','tags':['Mobile Growth'],'summary':'Xóa mềm một số đo',
 'description':'Requires edit. Verify child ownership and access before looking up record. In one child-locked transaction soft-delete and invalidate all evaluations depending on primary or paired FK; no R execution needed. Same authorized already-deleted ID returns 204. Nonexistent/other-child/no-view is 404, view-only is 403. Re-adding same metric/day creates a new active ID. Reload overview/detail/velocity after success; absence of response body is expected.',
 'parameters':parameters('ChildId','MeasurementId'),'responses':{'204':{'description':'Deletion committed or already deleted; no body.','headers':HEADERS},
 **{str(code):{'$ref':'#/components/responses/'+name} for code,name in [(401,'Unauthorized'),(403,'Forbidden'),(404,'NotFound'),(422,'ValidationError'),(503,'DatabaseUnavailable')]}}}}

responses={}
for name,code,description in [('Unauthorized','ACCESS_TOKEN_EXPIRED','Missing/invalid/expired/revoked mobile access. Refresh through existing auth; no growth token store.'),
                              ('Forbidden','UNAUTHORIZED_CAREGIVER','Authenticated but view-only for this edit, or account unavailable.'),
                              ('NotFound','RESOURCE_NOT_FOUND','Child/measurement missing or no view permission. Do not reveal another child exists.'),
                              ('ValidationError','VALIDATION_ERROR','Malformed fields/query or semantic date/metric/position error. error.fields identifies fields; specific request codes may be used.'),
                              ('DatabaseUnavailable','DATABASE_UNAVAILABLE','Database unavailable before confirmed completion, or AUTH_NOT_CONFIGURED from the existing auth readiness dependency. A transport timeout does not prove a mutation rolled back; reconcile using GET day before resubmission.')]:
    example=copy.deepcopy(ERROR);example['error'].update(code=code,message=code,fields={})
    responses[name]=response('ErrorResponse',description)
    responses[name]['content']['application/json'].pop('examples')
    responses[name]['content']['application/json']['example']=example
    if name=='Unauthorized':
        responses[name]['headers']['WWW-Authenticate']={'schema':{'type':'string'},'description':'Bearer challenge for 401.'}

doc={'openapi':'3.1.0','jsonSchemaDialect':'https://json-schema.org/draft/2020-12/schema',
     'info':{'title':'Track Children - Mobile Growth API','version':'1.0.0',
             'description':'API growth triển khai ngày 29/10/2026 theo docs/core_growth; backend và repository Flutter remote đã có mã và kiểm thử tích hợp HTTP. Sáu operations cho giao diện growth mới. JSON camelCase, base /api/v1, current mobile Bearer session. PostgreSQL chỉ growth.measurements/evaluations; WHO static, velocity on read. Input kg/cm; BMI và Z từ backend normalization/anthro. Synthetic examples illustrate contract, not verified WHO reference datasets. No automatic demo-data upload. Runtime data still respects mapping review gates. Deployment/device QA and existing auth migration issues are tracked in GROWTH-RUNTIME-README.md.'},
     'servers':[{'url':'http://localhost:8000/api/v1','description':'Local growth backend'}],
     'tags':[{'name':'Mobile Growth','description':'Growth overview, metric detail/chart/history, velocity and daily measurements.'}],
     'security':[{'MobileBearer':[]}], 'x-implementation-status':'IMPLEMENTED',
     'x-status-contract-version':STATUS['schema_version'],
     'x-screen-operations':{'overview':['getGrowthOverview'],'weightDetail':['getGrowthMetricDetail','getGrowthVelocity'],
                            'statureDetail':['getGrowthMetricDetail','getGrowthVelocity'],'headDetail':['getGrowthMetricDetail','getGrowthVelocity'],
                            'bmiDetail':['getGrowthMetricDetail'],'measurementForm':['getGrowthDay','upsertGrowthDay'],
                            'history':['getGrowthMetricDetail','deleteGrowthMeasurement'],'homeMeasurement':['getGrowthDay','upsertGrowthDay']},
     'paths':paths,'components':{'securitySchemes':{'MobileBearer':{'type':'http','scheme':'bearer','bearerFormat':'JWT','description':'Existing parent mobile auth session; server checks token and current account/session plus child scope growth.'}},
                               'schemas':S,'parameters':PARAMS,'responses':responses,
                               'examples':{name:{'summary':name,'value':value} for name,value in EXAMPLES.items()}}}


if __name__=='__main__':
    OUT.write_text(json.dumps(doc,ensure_ascii=False,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'{OUT.name}: {len(paths)} paths, 6 operations, {len(S)} schemas')
