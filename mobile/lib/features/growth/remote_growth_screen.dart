import 'growth_classification_labels.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/demo_store.dart';
import 'growth_visuals.dart';
import 'remote_growth_repository.dart';

const _metrics = ['weight', 'height', 'head_circumference', 'bmi'];
const _titles = ['Cân nặng', 'Chiều dài/chiều cao', 'Vòng đầu', 'BMI'];
const _assets = [
  'overview-weight',
  'overview-height',
  'overview-head',
  'overview-bmi',
];
const _colors = [
  Color(0xFFCC762A),
  Color(0xFF4B92C6),
  Color(0xFF9468B5),
  Color(0xFF438B52),
];
const _chartTitles = {
  'WFA_AGE': 'Cân nặng theo tuổi',
  'LHFA_AGE': 'Chiều dài/chiều cao theo tuổi',
  'HCFA_AGE': 'Vòng đầu theo tuổi',
  'BMIFA_AGE': 'BMI theo tuổi',
  'WFL_LENGTH': 'Cân nặng theo chiều dài nằm',
  'WFH_HEIGHT': 'Cân nặng theo chiều cao đứng',
};

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _number(dynamic n) =>
    n is num ? n.toStringAsFixed(2).replaceAll('.', ',') : '—';
List<Map<String, dynamic>> _maps(dynamic values) => (values as List? ?? [])
    .map((v) => Map<String, dynamic>.from(v as Map))
    .toList();
String growthErrorMessage(Object error) => error is AuthException
    ? (error.code == 'RESOURCE_NOT_FOUND'
          ? 'Chưa tìm thấy hồ sơ trẻ trên máy chủ hoặc bạn chưa có quyền xem.'
          : error.toString())
    : 'Chưa tải được dữ liệu tăng trưởng. Vui lòng thử lại.';

/// Real account flow. No fallback to the preview repository on network failures.
class RemoteGrowthScreen extends StatelessWidget {
  const RemoteGrowthScreen({
    super.key,
    this.repository,
    this.initialMetric,
    this.openEditor = false,
  });
  final RemoteGrowthRepository? repository;
  final String? initialMetric;
  final bool openEditor;
  @override
  Widget build(BuildContext context) {
    if (repository != null) {
      return _RemoteOverview(
        repository: repository!,
        initialMetric: initialMetric,
        openEditor: openEditor,
      );
    }
    return AnimatedBuilder(
      animation: DemoStore.instance,
      builder: (context, _) {
        final id = DemoStore.instance.child?['id']?.toString();
        if (!AuthService.instance.signedIn || id == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Theo dõi tăng trưởng')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Đăng nhập và chọn hồ sơ trẻ để xem số đo đã lưu trên máy chủ.',
                ),
              ),
            ),
          );
        }
        return _RemoteOverview(
          key: ValueKey('${AuthService.instance.user?['id']}:$id'),
          repository: RemoteGrowthRepository(id),
          initialMetric: initialMetric,
          openEditor: openEditor,
        );
      },
    );
  }
}

class _RemoteOverview extends StatefulWidget {
  const _RemoteOverview({
    super.key,
    required this.repository,
    this.initialMetric,
    required this.openEditor,
  });
  final RemoteGrowthRepository repository;
  final String? initialMetric;
  final bool openEditor;
  @override
  State<_RemoteOverview> createState() => _RemoteOverviewState();
}

class _RemoteOverviewState extends State<_RemoteOverview> {
  late Future<GrowthDocument> _data;
  bool _easy = false;
  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.initialMetric != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _open(widget.initialMetric!, edit: widget.openEditor),
      );
    }
  }

  void _reload() {
    _data = widget.repository.overview();
    _data.ignore();
  }

  Future<void> _open(String metric, {bool edit = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RemoteGrowthDetail(
          repository: widget.repository,
          metric: metric,
          easyRead: _easy,
          openEditor: edit,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Nunito'),
    ),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Theo dõi tăng trưởng'),
        actions: [
          IconButton(
            tooltip: 'Chế độ dễ đọc',
            onPressed: () => setState(() => _easy = !_easy),
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
      body: FutureBuilder<GrowthDocument>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Failure(snapshot.error!, () => setState(_reload));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _data;
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  doc.child['fullName'] as String,
                  style: TextStyle(
                    fontSize: _easy ? 28 : 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                for (final card in doc.list('cards'))
                  Builder(
                    builder: (_) {
                      final index = _metrics.indexOf(card['metric'] as String);
                      final latest = card['latest'] as Map?;
                      return Card(
                        color: _colors[index].withValues(alpha: .09),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: GrowthAsset(_assets[index], size: 42),
                          title: Text(
                            _titles[index],
                            style: TextStyle(
                              fontSize: _easy ? 22 : 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            latest == null
                                ? 'Chưa có đủ số đo'
                                : '${_number(latest['value'])} ${latest['unit']} · ${latest['measuredOn']}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(card['metric'] as String),
                        ),
                      );
                    },
                  ),
                if (doc.canEdit)
                  FilledButton.icon(
                    onPressed: () => _chooseMetric(
                      context,
                      (metric) => _open(metric, edit: true),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Cập nhật số đo'),
                  ),
                if (!doc.canEdit) const Text('Bạn có quyền xem số đo của bé.'),
              ],
            ),
          );
        },
      ),
    ),
  );
}

void _chooseMetric(BuildContext context, void Function(String) select) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            ListTile(
              leading: GrowthAsset(_assets[i], size: 32),
              title: Text(_titles[i]),
              onTap: () {
                Navigator.pop(ctx);
                select(_metrics[i]);
              },
            ),
        ],
      ),
    ),
  );
}

class RemoteGrowthDetail extends StatefulWidget {
  const RemoteGrowthDetail({
    super.key,
    required this.repository,
    required this.metric,
    this.easyRead = false,
    this.openEditor = false,
    this.initialMeasurement,
  });
  final RemoteGrowthRepository repository;
  final String metric;
  final bool easyRead, openEditor;
  final Map<String, dynamic>? initialMeasurement;
  @override
  State<RemoteGrowthDetail> createState() => _RemoteGrowthDetailState();
}

class _RemoteGrowthDetailState extends State<RemoteGrowthDetail> {
  GrowthDocument? _doc;
  Object? _error;
  int _generation = 0;
  int _tab = 0;
  int _ageRange = 0;
  String _mode = 'actual', _view = 'radius5';
  int _period = 2;
  String? _selected;
  bool _loading = true, _editorOpened = false;
  final _ranges = const [
    (0, 60, 'Toàn bộ'),
    (0, 3, '0–3 tháng'),
    (3, 6, '3–6 tháng'),
    (6, 9, '6–9 tháng'),
    (9, 12, '9–12 tháng'),
    (12, 36, '1–3 tuổi'),
    (36, 60, '3–5 tuổi'),
  ];
  bool get _velocity => widget.metric != 'bmi' && _tab == 1;
  bool get _history => _tab == (widget.metric == 'bmi' ? 1 : 2);
  Color get _color => _colors[_metrics.indexOf(widget.metric)];
  @override
  void initState() {
    super.initState();
    DemoStore.instance.addListener(_contextChanged);
    _load();
  }

  void _contextChanged() {
    if (mounted && !widget.repository.isCurrentContext) {
      _generation++;
      setState(() {
        _doc = null;
        _loading = false;
        _selected = null;
        _error = AuthException('SESSION_CHANGED', {});
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    DemoStore.instance.removeListener(_contextChanged);
    super.dispose();
  }

  Map<String, String> _query() {
    final birth = _doc == null
        ? null
        : DateTime.parse(_doc!.child['dateOfBirth'] as String);
    if (birth == null || _ageRange == 0) return {};
    DateTime anchor(int months) {
      final first = DateTime(birth.year, birth.month + months);
      final last = DateTime(first.year, first.month + 1, 0).day;
      return DateTime(first.year, first.month, math.min(birth.day, last));
    }

    final range = _ranges[_ageRange];
    return {
      'startOn': _date(anchor(range.$1)),
      'endBefore': _date(anchor(range.$2)),
    };
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _query();
      final doc = _velocity
          ? await widget.repository.velocity(
              widget.metric,
              mode: _mode,
              period: _mode == 'who' ? _period : null,
              query: query,
            )
          : await widget.repository.detail(
              widget.metric,
              query: {
                ...query,
                if (widget.metric == 'weight') 'statureView': _view,
              },
            );
      if (!mounted || generation != _generation) return;
      setState(() {
        _doc = doc;
        _loading = false;
      });
      if (widget.openEditor && !_editorOpened && doc.canEdit) {
        _editorOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _edit(measurement: widget.initialMeasurement);
          }
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit({Map<String, dynamic>? measurement}) async {
    if (_doc?.canEdit != true) return;
    if (widget.metric == 'bmi') {
      _chooseMetric(context, (metric) async {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => RemoteGrowthDetail(
              repository: widget.repository,
              metric: metric,
              easyRead: widget.easyRead,
              openEditor: true,
            ),
          ),
        );
        if (mounted) _load();
      });
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _MeasurementEditor(
        repository: widget.repository,
        metric: widget.metric,
        birth: DateTime.parse(_doc!.child['dateOfBirth'] as String),
        measurement: measurement,
      ),
    );
    if (saved == true && mounted) {
      _selected = null;
      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> measurement) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa số đo này?'),
        content: Text(
          '${measurement['measuredOn']} · ${measurement['value']} ${measurement['unit']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await widget.repository.delete(measurement['id'] as String);
      _selected = null;
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  String _errorText(Object error) => growthErrorMessage(error);
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Nunito'),
      colorScheme: ColorScheme.fromSeed(seedColor: _color),
      scaffoldBackgroundColor: Colors.white,
    ),
    child: Scaffold(
      appBar: AppBar(
        title: Text(_titles[_metrics.indexOf(widget.metric)]),
        actions: [
          if (_doc?.canEdit == true)
            IconButton(
              tooltip: 'Cập nhật số đo',
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              for (final label
                  in (widget.metric == 'bmi'
                          ? ['Tổng quan', 'Lịch sử']
                          : ['Tổng quan', 'Tốc độ', 'Lịch sử'])
                      .asMap()
                      .entries)
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _tab = label.key;
                      _selected = null;
                      _load();
                    },
                    child: Text(
                      label.value,
                      style: TextStyle(
                        fontWeight: _tab == label.key
                            ? FontWeight.w800
                            : FontWeight.normal,
                        color: _tab == label.key ? _color : Colors.grey,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DropdownButtonFormField<int>(
              initialValue: _ageRange,
              decoration: const InputDecoration(labelText: 'Khoảng tuổi'),
              items: [
                for (var i = 0; i < _ranges.length; i++)
                  DropdownMenuItem(value: i, child: Text(_ranges[i].$3)),
              ],
              onChanged: (value) {
                _ageRange = value!;
                _selected = null;
                _load();
              },
            ),
          ),
          if (_velocity)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _mode,
                      items: const [
                        DropdownMenuItem(
                          value: 'actual',
                          child: Text('Tốc độ thực tế'),
                        ),
                        DropdownMenuItem(
                          value: 'who',
                          child: Text('Đối chiếu WHO'),
                        ),
                      ],
                      onChanged: (value) {
                        _mode = value!;
                        _load();
                      },
                    ),
                  ),
                  if (_mode == 'who')
                    DropdownButton<int>(
                      value: _period,
                      items: [
                        for (final i
                            in widget.metric == 'weight'
                                ? [1, 2, 3, 4, 6]
                                : [2, 3, 4, 6])
                          DropdownMenuItem(
                            value: i,
                            child: Text('Kỳ $i tháng'),
                          ),
                      ],
                      onChanged: (value) {
                        _period = value!;
                        _load();
                      },
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _Failure(_error!, _load)
                : _doc == null
                ? const SizedBox()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: _velocity
                          ? _velocityBody()
                          : _history
                          ? _historyBody()
                          : _chartBody(),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _chartBody() => [
    for (final chart in _doc!.list('charts')) ...[
      Text(
        _chartTitles[chart['chartId']] ?? 'Biểu đồ tăng trưởng',
        style: TextStyle(
          fontSize: widget.easyRead ? 23 : 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (['wfl', 'wfh'].contains(chart['indicator']))
        DropdownButton<String>(
          value: _view,
          items: const [
            DropdownMenuItem(value: 'radius5', child: Text('±5 cm')),
            DropdownMenuItem(value: 'radius10', child: Text('±10 cm')),
            DropdownMenuItem(value: 'all', child: Text('Toàn miền')),
          ],
          onChanged: (v) {
            _view = v!;
            _load();
          },
        ),
      _ServerChart(
        chart: chart,
        color: _color,
        onSelect: (point) => setState(
          () => _selected = '${point['measurementId']}:${chart['indicator']}',
        ),
      ),
      if ((chart['reference'] as Map)['importStatus'] != 'VERIFIED')
        const Text(
          'Chưa có đường chuẩn WHO đã kiểm định; vẫn xem được số đo của bé.',
        ),
      if (_maps(chart['childPoints']).isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Chưa đủ số đo hợp lệ cho biểu đồ này.'),
        ),
      for (final point in _maps(chart['childPoints']))
        ListTile(
          selected:
              _selected == '${point['measurementId']}:${chart['indicator']}',
          title: Text(
            '${point['measuredOn']} · ${_number(point['y'])} ${point['unit']}',
          ),
          subtitle: Text(
            'Tuổi: ${point['ageLabel']} · ${_assessmentLabel(point['assessment'] as Map)}',
          ),
          onTap: () => setState(
            () => _selected = '${point['measurementId']}:${chart['indicator']}',
          ),
          trailing: const Icon(Icons.info_outline),
        ),
      for (final point in _maps(chart['childPoints']).where(
        (p) =>
            _selected == '${p['measurementId']}:${chart['indicator']}' ||
            (_selected == null &&
                p['measurementId'] ==
                    _maps(chart['childPoints']).lastOrNull?['measurementId']),
      )) ...[_PointExplanation(point: point)],
      for (final omitted in _maps(chart['omittedPoints']))
        Text('${omitted['measuredOn']}: ${_reason(omitted['reason'])}'),
      const SizedBox(height: 24),
    ],
    if (_doc!.data['meta'] case final Map meta
        when meta['calculationPending'] == true)
      TextButton(
        onPressed: _load,
        child: const Text('Một số đánh giá đang chờ tính. Tải lại kết quả'),
      ),
  ];

  List<Widget> _historyBody() {
    if (widget.metric == 'bmi') {
      final samples = _doc!.list('samples');
      return [
        if (samples.isEmpty)
          const Text('Chưa đủ cặp số đo cùng ngày để tính BMI.'),
        for (final sample in samples.reversed)
          Card(
            child: ExpansionTile(
              title: Text(
                "${sample['measuredOn']} - BMI ${_number(sample['value'])} kg/m²",
              ),
              subtitle: const Text(
                'BMI từ cặp cân nặng và chiều dài/chiều cao cùng ngày',
              ),
              children: [
                for (final m
                    in _doc!
                        .list('measurements')
                        .where(
                          (m) =>
                              m['id'] == sample['measurementId'] ||
                              m['id'] == sample['pairedMeasurementId'],
                        ))
                  _measurementRow(m),
              ],
            ),
          ),
      ];
    }
    final rows = _doc!
        .list('measurements')
        .where((m) => m['metric'] == widget.metric)
        .toList();
    return [
      if (rows.isEmpty) const Text('Chưa có số đo trong khoảng đã chọn.'),
      for (final m in rows.reversed) Card(child: _measurementRow(m)),
    ];
  }

  Widget _measurementRow(Map<String, dynamic> m) => ListTile(
    title: Text("${m['measuredOn']} - ${_number(m['value'])} ${m['unit']}"),
    subtitle: Text(_titles[_metrics.indexOf(m['metric'] as String)]),
    trailing: !_doc!.canEdit
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Sửa số đo',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  if (m['metric'] == widget.metric) {
                    await _edit(measurement: m);
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => RemoteGrowthDetail(
                          repository: widget.repository,
                          metric: m['metric'] as String,
                          openEditor: true,
                          initialMeasurement: m,
                        ),
                      ),
                    );
                    if (mounted) {
                      _load();
                    }
                  }
                },
              ),
              IconButton(
                tooltip: 'Xóa số đo',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(m),
              ),
            ],
          ),
  );

  List<Widget> _velocityBody() {
    final intervals = _doc!.list(
      _mode == 'actual' ? 'actualIntervals' : 'whoIntervals',
    );
    return [
      Text(
        _mode == 'actual'
            ? 'Tốc độ quy đổi theo tháng 30,4375 ngày'
            : 'Mức tăng trong toàn khoảng WHO',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      if (intervals.isEmpty)
        Text(
          _reason(
            _doc!.data['referenceReason'] ?? _doc!.data['calculationStatus'],
          ),
        ),
      if (intervals.isNotEmpty)
        SizedBox(
          height: 220,
          child: CustomPaint(
            painter: _IntervalPainter(intervals, _mode == 'actual', _color),
          ),
        ),
      if (_mode == 'who' && intervals.isNotEmpty)
        const Text(
          'Dải tham chiếu −2 SD đến +2 SD; vạch giữa là trung vị WHO theo từng khoảng đo.',
        ),
      _ContentView(content: _doc!.data['content'] as Map),
      for (final interval in intervals)
        Card(
          child: ExpansionTile(
            title: Text(
              '${(interval['from'] as Map)['measuredOn']} → ${(interval['to'] as Map)['measuredOn']}',
            ),
            subtitle: Text(
              '${_number(_mode == 'actual' ? interval['ratePerMonth'] : interval['deltaValue'])} ${_mode == 'actual' ? interval['rateUnit'] : interval['deltaUnit']} · ${interval['elapsedDays']} ngày',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mức thay đổi: ${_number(interval['deltaValue'])} ${interval['deltaUnit']}',
                    ),
                    Text(
                      _reason(
                        interval['referenceReason'] ??
                            interval['referenceStatus'],
                      ),
                    ),
                    if (interval['zScore'] != null)
                      Text('Z-score tốc độ: ${_number(interval['zScore'])}'),
                    if (interval['matchedReference']
                        case final Map matched) ...[
                      Text('Khoảng WHO: ${matched['intervalLabel']}'),
                      for (final sd in _maps(matched['sdValues']))
                        Text(
                          '${sd['sd']} SD: ${_number(sd['value'])} ${interval['deltaUnit']}',
                        ),
                    ],
                    _ContentView(content: interval['content'] as Map),
                    if (interval['zScoreContent'] case final Map c)
                      _ContentView(content: c),
                  ],
                ),
              ),
            ],
          ),
        ),
      if (_doc!.data['trend'] case final Map trend)
        _ContentView(content: trend['content'] as Map),
    ];
  }
}

String _reason(dynamic code) => switch (code) {
  'MISSING_PAIRED_MEASUREMENT' =>
    'Cần cân nặng và chiều dài/chiều cao cùng ngày.',
  'INVALID_MEASURE_POSITION' => 'Cần kiểm tra lại tư thế đo.',
  'WHO_FLAGGED' => 'Số đo cần được kiểm tra lại trước khi đánh giá.',
  'R_TIMEOUT' ||
  'R_BUSY' ||
  'R_EXECUTION_FAILED' => 'Đã có số đo; hệ thống chưa tính được đánh giá.',
  'REFERENCE_NOT_VERIFIED' ||
  'REFERENCE_UNVERIFIED' => 'Bảng WHO chưa được kiểm định cho đối chiếu.',
  'MISSING_REFERENCE_FILE' => 'Chưa có bảng tham chiếu WHO phù hợp.',
  'NO_MATCHING_INTERVAL' || 'NO_EXACT_REFERENCE' =>
    'Khoảng đo chưa khớp mốc WHO; chỉ xem tốc độ thực tế.',
  'REFERENCE_MATCHED' =>
    'Có đối chiếu WHO đúng khoảng; đây không phải chẩn đoán.',
  'OUT_OF_SCOPE_AGE' => 'Khoảng đo ngoài phạm vi đối chiếu WHO của ứng dụng.',
  'INSUFFICIENT_MEASUREMENTS' => 'Cần ít nhất hai số đo hợp lệ để tính tốc độ.',
  'PENDING_CALCULATION' => 'Đang chờ tính đánh giá.',
  'METHOD_NOT_VERIFIED' =>
    'Phương pháp tính Z-score tốc độ chưa được kiểm định.',
  null => '',
  _ => 'Chưa đủ điều kiện đánh giá cho số đo này.',
};
String _assessmentLabel(Map a) => a['status'] == 'READY'
    ? 'Z = ${_number(a['zScore'])}${a['classificationCode'] == null ? '' : ' · ${growthClassificationLabel(a['indicator']?.toString(), a['classificationCode']?.toString()) ?? 'Có kết quả đánh giá'}'}'
    : _reason(a['reason'] ?? a['status']);

class _PointExplanation extends StatelessWidget {
  const _PointExplanation({required this.point});
  final Map point;
  @override
  Widget build(BuildContext context) {
    final a = point['assessment'] as Map;
    final norm = point['normalization'] as Map?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đánh giá ${a['indicator'].toString().toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(_assessmentLabel(a)),
            if (norm != null)
              Text(
                'Số đo chuẩn hóa: ${_number(norm['normalizedLenheiCm'])} cm · Hiệu chỉnh ${norm['adjustmentCm']} cm',
              ),
            if (point['pairedMeasurementId'] != null)
              const Text('Sử dụng cặp số đo cùng ngày.'),
            _ContentView(content: a['content'] as Map),
          ],
        ),
      ),
    );
  }
}

class _ContentView extends StatelessWidget {
  const _ContentView({required this.content});
  final Map content;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text((content['comment'] as Map)['text'] as String),
      for (final advice in _maps(content['advice']))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(advice['text'] as String),
        ),
      for (final advice in _maps(content['ageContext']))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(advice['text'] as String),
        ),
    ],
  );
}

class _Failure extends StatelessWidget {
  const _Failure(this.error, this.retry);
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(growthErrorMessage(error)),
          const SizedBox(height: 16),
          TextButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

class _MeasurementEditor extends StatefulWidget {
  const _MeasurementEditor({
    required this.repository,
    required this.metric,
    required this.birth,
    this.measurement,
  });
  final RemoteGrowthRepository repository;
  final String metric;
  final DateTime birth;
  final Map<String, dynamic>? measurement;
  @override
  State<_MeasurementEditor> createState() => _MeasurementEditorState();
}

class _MeasurementEditorState extends State<_MeasurementEditor> {
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _note = TextEditingController();
  late DateTime _day;
  String _position = 'lying';
  bool _busy = true, _loaded = false;
  String? _message;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    DemoStore.instance.addListener(_contextChanged);
    _day = widget.measurement == null
        ? DateUtils.dateOnly(DateTime.now())
        : DateTime.parse(widget.measurement!['measuredOn'] as String);
    _readDay();
  }

  void _contextChanged() {
    if (mounted && !widget.repository.isCurrentContext) {
      _generation++;
      _value.clear();
      _note.clear();
      setState(() {
        _loaded = false;
        _busy = false;
        _message =
            'Hồ sơ hoặc phiên đăng nhập đã thay đổi. Hãy mở lại màn số đo.';
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    DemoStore.instance.removeListener(_contextChanged);
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _readDay() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _loaded = false;
      _message = null;
    });
    try {
      final data = await widget.repository.day(_date(_day));
      if (!mounted || generation != _generation) return;
      final record = data
          .list('measurements')
          .where((r) => r['metric'] == widget.metric)
          .firstOrNull;
      _value.text = record == null ? '' : record['value'].toString();
      _note.text = record?['note']?.toString() ?? '';
      _position =
          record?['measurePosition'] as String? ??
          (_day.difference(widget.birth).inDays < 731 ? 'lying' : 'standing');
      setState(() {
        _busy = false;
        _loaded = true;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _message = growthErrorMessage(error);
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final value = double.parse(_value.text.replaceAll(',', '.'));
      final result = await widget.repository.save(_date(_day), {
        if (widget.metric == 'weight') 'weightKg': value,
        if (widget.metric == 'height')
          'height': {'value': value, 'measurePosition': _position},
        if (widget.metric == 'head_circumference') 'headCircumferenceCm': value,
        'note': _note.text.isEmpty ? null : _note.text,
      });
      if (!mounted) return;
      final unavailable = result
          .list('assessments')
          .any((a) => a['status'] == 'CALCULATION_UNAVAILABLE');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unavailable
                ? 'Đã lưu số đo. Đánh giá sẽ được tính lại khi tải dữ liệu.'
                : 'Đã lưu số đo của bé.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = growthErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cập nhật ${_titles[_metrics.indexOf(widget.metric)].toLowerCase()}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                onPressed:
                    _busy ||
                        widget.measurement != null ||
                        !widget.repository.isCurrentContext
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _day,
                          firstDate: widget.birth,
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && mounted) {
                          _day = picked;
                          _readDay();
                        }
                      },
                child: Text(_date(_day)),
              ),
              if (widget.measurement != null)
                const Text('Đang sửa số đo của ngày này.'),
              TextFormField(
                controller: _value,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: widget.metric == 'weight'
                      ? 'Cân nặng (kg)'
                      : 'Số đo (cm)',
                ),
                validator: (raw) {
                  final n = double.tryParse((raw ?? '').replaceAll(',', '.'));
                  return n == null ||
                          !n.isFinite ||
                          n <= 0 ||
                          !RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(raw ?? '')
                      ? 'Nhập số dương, tối đa 2 chữ số thập phân.'
                      : null;
                },
              ),
              if (widget.metric == 'height')
                DropdownButtonFormField<String>(
                  initialValue: _position,
                  key: ValueKey(_position),
                  decoration: const InputDecoration(labelText: 'Tư thế đo'),
                  items: const [
                    DropdownMenuItem(value: 'lying', child: Text('Đo nằm')),
                    DropdownMenuItem(value: 'standing', child: Text('Đo đứng')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _position = value!),
                ),
              TextFormField(
                controller: _note,
                enabled: !_busy,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
              if (_message != null)
                Text(_message!, style: const TextStyle(color: Colors.red)),
              if (!_loaded && !_busy)
                TextButton(
                  onPressed: _readDay,
                  child: const Text('Tải lại số đo của ngày'),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || !_loaded ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Lưu số đo'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ServerChart extends StatelessWidget {
  const _ServerChart({
    required this.chart,
    required this.color,
    required this.onSelect,
  });
  final Map chart;
  final Color color;
  final ValueChanged<Map<String, dynamic>> onSelect;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '${(chart['yAxis'] as Map)['unit']} theo ${(chart['xAxis'] as Map)['type'] == 'age_days' ? 'tuổi (ngày)' : 'chiều dài/chiều cao (cm)'}',
      ),
      Semantics(
        label:
            'Biểu đồ ${chart['indicator']}. Các điểm số đo và đánh giá có trong danh sách bên dưới.',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final painter = _ChartPainter(chart, color);
            void select(Offset position) {
              final hits =
                  painter.hitPoints
                      .where((hit) => (hit.$1 - position).distance < 20)
                      .toList()
                    ..sort(
                      (a, b) => (a.$1 - position).distance.compareTo(
                        (b.$1 - position).distance,
                      ),
                    );
              if (hits.isNotEmpty) onSelect(hits.first.$2);
            }

            return GestureDetector(
              onTapDown: (event) => select(event.localPosition),
              child: MouseRegion(
                onHover: (event) => select(event.localPosition),
                child: SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: CustomPaint(painter: painter),
                ),
              ),
            );
          },
        ),
      ),
      const Wrap(
        spacing: 12,
        children: [
          Text('−3 SD'),
          Text('−2 SD'),
          Text('−1 SD'),
          Text('0 SD'),
          Text('+1 SD'),
          Text('+2 SD'),
          Text('+3 SD'),
        ],
      ),
    ],
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.chart, this.color);
  final Map chart;
  final Color color;
  final hitPoints = <(Offset, Map<String, dynamic>)>[];
  @override
  void paint(Canvas canvas, Size size) {
    hitPoints.clear();
    final points = _maps(chart['childPoints']);
    final segments = _maps((chart['reference'] as Map)['segments']);
    final coordinates = <Offset>[];
    for (final p in points) {
      coordinates.add(
        Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
      );
    }
    for (final segment in segments) {
      for (final curve in _maps(segment['curves'])) {
        for (final p in _maps(curve['points'])) {
          coordinates.add(
            Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
          );
        }
      }
    }
    if (coordinates.isEmpty) return;
    final xmin = coordinates.map((p) => p.dx).reduce(math.min),
        xmax = coordinates.map((p) => p.dx).reduce(math.max);
    final ymin = coordinates.map((p) => p.dy).reduce(math.min),
        ymax = coordinates.map((p) => p.dy).reduce(math.max);
    Offset screen(Offset p) => Offset(
      40 + (p.dx - xmin) / math.max(1, xmax - xmin) * (size.width - 54),
      size.height -
          30 -
          (p.dy - ymin) / math.max(1, ymax - ymin) * (size.height - 50),
    );
    final pen = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(40, 10), Offset(40, size.height - 30), pen);
    canvas.drawLine(
      Offset(40, size.height - 30),
      Offset(size.width - 10, size.height - 30),
      pen,
    );
    void label(String text, Offset offset) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: Colors.black54, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, offset);
    }

    for (var i = 0; i <= 4; i++) {
      final y = ymin + (ymax - ymin) * i / 4;
      final sy = screen(Offset(xmin, y)).dy;
      canvas.drawLine(Offset(40, sy), Offset(size.width - 10, sy), pen);
      label(y.toStringAsFixed(1), Offset(0, sy - 6));
      final x = xmin + (xmax - xmin) * i / 4;
      label(
        x.toStringAsFixed(0),
        Offset(screen(Offset(x, ymin)).dx - 8, size.height - 22),
      );
    }
    for (final segment in segments) {
      for (final curve in _maps(segment['curves'])) {
        final path = Path();
        var first = true;
        for (final p in _maps(curve['points'])) {
          final pos = screen(
            Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
          );
          if (first) {
            path.moveTo(pos.dx, pos.dy);
            first = false;
          } else {
            path.lineTo(pos.dx, pos.dy);
          }
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = curve['sd'] == 0 ? 1.8 : 1
            ..color = (curve['sd'] == 0 ? Colors.green : Colors.blueGrey)
                .withValues(alpha: .45),
        );
      }
    }
    for (final p in points) {
      final position = screen(
        Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
      );
      hitPoints.add((position, p));
      canvas.drawCircle(position, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.chart != chart;
}

class _IntervalPainter extends CustomPainter {
  _IntervalPainter(this.intervals, this.actual, this.color);
  final List<Map<String, dynamic>> intervals;
  final bool actual;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final values = intervals
        .map(
          (i) =>
              (i[actual ? 'ratePerMonth' : 'deltaValue'] as num?)?.toDouble() ??
              0,
        )
        .toList();
    if (values.isEmpty) return;
    final domain = [...values];
    if (!actual) {
      for (final interval in intervals) {
        if (interval['matchedReference'] case final Map reference) {
          domain.addAll(
            _maps(reference['sdValues'])
                .map((sd) => (sd['value'] as num).toDouble()),
          );
        }
      }
    }
    final low = math.min(0.0, domain.reduce(math.min)),
        high = math.max(1.0, domain.reduce(math.max));
    double y(double value) =>
        10 + (high - value) / (high - low) * (size.height - 30);
    canvas.drawLine(
      Offset(0, y(0)),
      Offset(size.width, y(0)),
      Paint()..color = Colors.grey,
    );
    final width = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      if (!actual) {
        if (intervals[i]['matchedReference'] case final Map reference) {
          final sd = {
            for (final point in _maps(reference['sdValues']))
              point['sd']: (point['value'] as num).toDouble(),
          };
          canvas.drawRect(
            Rect.fromLTRB(i * width, y(sd[2]!), (i + 1) * width, y(sd[-2]!)),
            Paint()..color = Colors.blueGrey.withValues(alpha: .12),
          );
          canvas.drawLine(
            Offset(i * width, y(sd[0]!)),
            Offset((i + 1) * width, y(sd[0]!)),
            Paint()
              ..color = Colors.green
              ..strokeWidth = 1.5,
          );
        }
      }
      final top = math.min(y(0), y(values[i])),
          bottom = math.max(y(0), y(values[i]));
      canvas.drawRect(
        Rect.fromLTWH(
          i * width + 3,
          top,
          math.max(1, width - 6),
          math.max(1, bottom - top),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IntervalPainter oldDelegate) =>
      oldDelegate.intervals != intervals || oldDelegate.actual != actual;
}
