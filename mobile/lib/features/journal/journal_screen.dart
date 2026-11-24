import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_colors.dart';
import '../../app_date_picker.dart';
import '../../app_layout.dart';
import '../../models/video_insight.dart';
import '../../services/demo_store.dart';
import '../sharing/access_gate.dart';
import '../../services/journal_media.dart';
import 'ai_videos_screen.dart';
import 'journal_media_view.dart';
import 'journal_theme.dart';
import 'video_insight_view.dart';

/// Mở màn hình viết nhật ký mới cho bé.
/// Nếu không truyền [childId], hàm sẽ dùng hồ sơ bé đang chọn trong [DemoStore].
Future<void> openAddJournal(BuildContext context, {String? childId}) async {
  final targetChildId = childId ?? DemoStore.instance.child?['id'] as String?;
  if (targetChildId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng chọn hồ sơ bé để viết nhật ký.')),
    );
    return;
  }
  if (!DemoStore.instance.canEditChild(targetChildId, 'diary')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bạn không có quyền thêm nhật ký cho bé này.')),
    );
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => JournalEditorScreen(childId: targetChildId),
    ),
  );
}

const _heading = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: JournalColors.textPrimary,
);
const _title = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: JournalColors.textPrimary,
);
const _body = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: JournalColors.textPrimary,
);
const _caption = TextStyle(
  fontSize: 12,
  height: 1.5,
  color: JournalColors.textSecondary,
);
const _moods = ['Vui vẻ', 'Bình thường', 'Quấy'];
const _domains = [
  'Vận động thô',
  'Vận động tinh',
  'Ngôn ngữ',
  'Xã hội – Cảm xúc',
];
String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.childId});
  final String childId;
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    // Gửi nhật ký còn chờ + lấy bản mới nhất (vd bố ghi trên máy khác).
    DemoStore.instance.syncJournal(widget.childId);
  }

  @override
  void didUpdateWidget(JournalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId) {
      DemoStore.instance.syncJournal(widget.childId);
    }
  }

  Future<void> _filter() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
      helpText: 'Chọn khoảng thời gian',
      saveText: 'Áp dụng',
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  void _open([Map<String, dynamic>? entry]) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          JournalEditorScreen(childId: widget.childId, entry: entry),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final child = DemoStore.instance.childById(widget.childId);
      final canView = DemoStore.instance.canViewChild(widget.childId, 'diary');
      final canEdit = DemoStore.instance.canEditChild(widget.childId, 'diary');
      final entries = DemoStore.instance.journalEntries(widget.childId).where((
        entry,
      ) {
        final date = DateTime.parse(entry['date'] as String);
        return _range == null ||
            (!date.isBefore(_range!.start) &&
                date.isBefore(_range!.end.add(const Duration(days: 1))));
      }).toList();
      return JournalTheme(
        builder: (context) => Scaffold(
          backgroundColor: JournalColors.background,
          appBar: AppBar(
            backgroundColor: JournalColors.background,
            foregroundColor: JournalColors.textPrimary,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            iconTheme: const IconThemeData(color: JournalColors.textPrimary),
            title: const Text('Nhật ký', style: _heading),
            actions: [
              if (child != null && canView)
                IconButton(
                  tooltip: 'Video đã phân tích AI',
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => AiVideosScreen(childId: widget.childId),
                    ),
                  ),
                  icon: const Icon(Icons.insights_outlined),
                ),
              IconButton(
                tooltip: 'Lọc theo thời gian',
                onPressed: _filter,
                icon: const Icon(Icons.date_range_outlined),
              ),
            ],
          ),
          floatingActionButton: child == null || !canEdit
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _open(),
                  backgroundColor: JournalColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Viết nhật ký'),
                ),
          body: child == null
              ? const Center(child: Text('Chọn hồ sơ bé để xem nhật ký.'))
              : !canView
              ? const NoAccessView(section: 'nhật ký')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.pagePadding,
                    8,
                    AppLayout.pagePadding,
                    100,
                  ),
                  children: [
                    if (!canEdit) const ReadOnlyNotice(),
                    if (_range != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _Panel(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_dateLabel(_range!.start)} – ${_dateLabel(_range!.end)}',
                                  style: _body,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Bỏ lọc thời gian',
                                onPressed: () => setState(() => _range = null),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Text(
                      '${entries.length} nhật ký${_range == null ? '' : ' trong khoảng đã chọn'}',
                      style: _title,
                    ),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      _Panel(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.edit_note_rounded,
                              size: 48,
                              color: JournalColors.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _range == null
                                  ? 'Chưa có nhật ký nào'
                                  : 'Không có nhật ký trong khoảng này',
                              style: _title,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Mỗi khoảnh khắc cùng bé đều đáng được lưu giữ.',
                              style: _body,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    for (final entry in entries)
                      RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _Panel(
                            onTap: () => _open(entry),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: JournalColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _dateLabel(
                                          DateTime.parse(entry['date'] as String),
                                        ),
                                        style: _caption,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: JournalColors.textSecondary,
                                    ),
                                  ],
                                ),
                              if ((entry['media'] as List?)?.isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 12),
                                JournalMediaTile(
                                  childId: widget.childId,
                                  entryId: entry['id'] as String,
                                  media: Map<String, dynamic>.from(
                                    (entry['media'] as List).first as Map,
                                  ),
                                ),
                              ] else if (entry['photo'] != null) ...[
                                const SizedBox(height: 12),
                                _Photo(photo: entry['photo'] as String),
                              ],
                              const SizedBox(height: 12),
                              Text(entry['note'] as String? ?? '', style: _body),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _Tag(
                                    label: entry['mood'] as String? ?? 'Vui vẻ',
                                  ),
                                  if (entry['activityName'] != null)
                                    _Tag(label: entry['activityName'] as String),
                                  if (entry['insight'] != null)
                                    const _Tag(label: 'Có nhận xét AI'),
                                  for (final domain
                                      in entry['domains'] as List? ?? [])
                                    _Tag(label: domain.toString()),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        ),
      );
    },
  );
}

class JournalEditorScreen extends StatefulWidget {
  const JournalEditorScreen({super.key, required this.childId, this.entry});
  final String childId;
  final Map<String, dynamic>? entry;
  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _note;
  late DateTime _date;
  late String _mood;
  late Set<String> _selected;

  /// Ảnh / video của nhật ký (xem [JournalMediaFiles]).
  List<Map<String, dynamic>> _media = [];

  /// Ảnh base64 của nhật ký cũ (chưa chuyển thành file khi đồng bộ).
  String? _legacyPhoto;

  /// File chọn trong lần sửa này; không lưu thì xóa khỏi máy.
  final _newFiles = <String>{};
  bool _editing = false, _busy = false;
  VideoInsight? _insight;
  Timer? _poll;

  /// Bản mới nhất trong store (nhận xét AI có thể đã cập nhật sau khi mở màn).
  Map<String, dynamic>? _latestEntry() {
    final id = widget.entry?['id'];
    if (id == null) return null;
    return DemoStore.instance
            .journalEntries(widget.childId)
            .where((e) => e['id'] == id)
            .firstOrNull ??
        widget.entry;
  }

  void _pollInsight() {
    var attempts = 0;
    _poll = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (++attempts > 75) {
        timer.cancel();
        return;
      }
      try {
        final insight = await DemoStore.instance.refreshJournalInsight(
          widget.childId,
          widget.entry!['id'] as String,
        );
        if (insight == null) {
          timer.cancel();
          return;
        }
        if (mounted) setState(() => _insight = insight);
        if (insight.finished) timer.cancel();
      } catch (_) {
        // Mạng chập chờn: thử lại ở lần sau
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    final saved = entry?['insight'] as Map<String, dynamic>?;
    if (saved != null) {
      _insight = VideoInsight.fromJson(saved);
      if (!_insight!.finished) _pollInsight();
    }
    _editing = entry == null;
    _note = TextEditingController(text: entry?['note'] as String? ?? '');
    _date = entry == null
        ? DateTime.now()
        : DateTime.parse(entry['date'] as String);
    _mood = entry?['mood'] as String? ?? _moods.first;
    _selected = Set<String>.from(entry?['domains'] as List? ?? []);
    _media = [
      for (final m in entry?['media'] as List? ?? const [])
        Map<String, dynamic>.from(m as Map),
    ];
    _legacyPhoto = entry?['photo'] as String?;
  }

  @override
  void dispose() {
    for (final path in _newFiles) {
      JournalMediaFiles.instance.remove(path);
    }
    _poll?.cancel();
    _note.dispose();
    super.dispose();
  }

  void _error(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      if (file == null) return;
      final id = DemoStore.newMediaId();
      final path = await JournalMediaFiles.instance.keep(file, id);
      _newFiles.add(path);
      if (!mounted) return;
      // Mỗi nhật ký 1 ảnh: ảnh mới thay ảnh cũ, giữ video
      setState(() {
        _legacyPhoto = null;
        _media = [
          {'id': id, 'type': 'image', 'path': path, 'uploaded': false},
          ..._media.where((m) => m['type'] != 'image'),
        ];
      });
    } catch (_) {
      _error('Không mở được ảnh. Vui lòng kiểm tra quyền truy cập và thử lại.');
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final entry = {
        // Giữ hoạt động + nhận xét AI của nhật ký tạo từ chi tiết hoạt động
        ...?_latestEntry(),
        'id':
            widget.entry?['id'] ??
            'journal_${DateTime.now().microsecondsSinceEpoch}',
        'date': _date.toIso8601String(),
        'note': _note.text.trim(),
        'mood': _mood,
        'domains': _selected.toList(),
        'media': _media,
        'photo': _legacyPhoto,
      }..removeWhere((key, value) => key == 'photo' && value == null);
      await DemoStore.instance.saveJournalEntry(widget.childId, entry);
      final saved = {for (final m in _media) m['path']};
      // Ảnh chọn rồi đổi trong lúc sửa: không còn dùng
      for (final path in _newFiles.where((p) => !saved.contains(p))) {
        JournalMediaFiles.instance.remove(path);
      }
      _newFiles.clear();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _error('Chưa lưu được nhật ký. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: JournalColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Xóa nhật ký?',
          style: TextStyle(
            color: JournalColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Nhật ký này sẽ bị xóa và không thể khôi phục.',
          style: TextStyle(color: JournalColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: JournalColors.textSecondary,
            ),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await DemoStore.instance.deleteJournalEntry(
        widget.childId,
        widget.entry!['id'] as String,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _error('Chưa xóa được nhật ký. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => JournalTheme(
    builder: (context) => Scaffold(
      backgroundColor: JournalColors.background,
      appBar: AppBar(
        backgroundColor: JournalColors.background,
        foregroundColor: JournalColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: JournalColors.textPrimary),
        title: Text(
          widget.entry == null
              ? 'Viết nhật ký'
              : _editing
              ? 'Sửa nhật ký'
              : 'Chi tiết nhật ký',
          style: _heading,
        ),
        actions: [
          if (widget.entry != null &&
              !_editing &&
              DemoStore.instance.canEditChild(widget.childId, 'diary')) ...[
            IconButton(
              tooltip: 'Sửa nhật ký',
              onPressed: _busy ? null : () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Xóa nhật ký',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppLayout.pagePadding),
          children: [
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_editing) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            JournalColors.primaryDark,
                            JournalColors.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            color: JournalColors.accent,
                            size: 32,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Một ngày nhỏ,\nmột kỷ niệm lớn',
                            style: _heading.copyWith(
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ghi lại điều khiến bạn mỉm cười cùng bé hôm nay.',
                            style: _body.copyWith(
                              color: Colors.white.withValues(alpha: .9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const Text('Khoảnh khắc của bé', style: _title),
                  const SizedBox(height: 12),
                  if (_media.isEmpty && _legacyPhoto == null && _editing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: JournalColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: JournalColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: JournalColors.primary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Thêm một tấm ảnh đáng nhớ',
                            style: _title,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Một bức ảnh, cả một câu chuyện',
                            style: _caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  if (_legacyPhoto != null) ...[
                    _Photo(photo: _legacyPhoto!),
                    if (_editing)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: JournalColors.textSecondary,
                          ),
                          onPressed: _busy
                              ? null
                              : () => setState(() => _legacyPhoto = null),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Bỏ ảnh'),
                        ),
                      ),
                  ],
                  for (final media in _media) ...[
                    JournalMediaTile(
                      key: ValueKey(media['id']),
                      childId: widget.childId,
                      entryId: widget.entry?['id'] as String? ?? '',
                      media: media,
                    ),
                    if (_editing)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: JournalColors.textSecondary,
                          ),
                          onPressed: _busy
                              ? null
                              : () => setState(() => _media.remove(media)),
                          icon: const Icon(Icons.close_rounded),
                          label: Text(
                            media['type'] == 'video' ? 'Bỏ video' : 'Bỏ ảnh',
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                  if (_editing) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: JournalColors.primarySoft,
                            foregroundColor: JournalColors.primaryDark,
                          ),
                          onPressed: _busy
                              ? null
                              : () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Chụp ảnh'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: JournalColors.textPrimary,
                            side: const BorderSide(color: JournalColors.border),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Thư viện'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text('Câu chuyện hôm nay', style: _title),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    readOnly: !_editing || _busy,
                    minLines: 5,
                    maxLines: null,
                    style: _body,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Hãy ghi lại một khoảnh khắc của bé.'
                        : null,
                    decoration: InputDecoration(
                      hintText:
                          'Bé đã khám phá điều gì mới?\nMột cử chỉ, một tiếng cười hay một bước tiến nhỏ…',
                      hintStyle: _caption.copyWith(
                        color: JournalColors.textSecondary.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      filled: true,
                      fillColor: JournalColors.surface,
                      contentPadding: const EdgeInsets.all(16),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        borderSide: BorderSide(color: JournalColors.border),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        borderSide: BorderSide(color: JournalColors.border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        borderSide: BorderSide(
                          color: JournalColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_editing && _insight != null) ...[
              const SizedBox(height: 16),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Nhận xét của AI', style: _title),
                    if (widget.entry?['activityName'] != null)
                      Text(
                        'Hoạt động: ${widget.entry!['activityName']}',
                        style: _caption,
                      ),
                    const SizedBox(height: 12),
                    VideoInsightView(insight: _insight!),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cảm xúc của bé', style: _title),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mood in _moods)
                        ChoiceChip(
                          avatar: Icon(
                            mood == 'Vui vẻ'
                                ? Icons.sentiment_very_satisfied_rounded
                                : mood == 'Bình thường'
                                ? Icons.sentiment_neutral_rounded
                                : Icons.sentiment_dissatisfied_rounded,
                            color: _mood == mood
                                ? JournalColors.primaryDark
                                : JournalColors.textSecondary,
                          ),
                          label: Text(mood),
                          labelStyle: _body.copyWith(
                            color: _mood == mood
                                ? JournalColors.primaryDark
                                : JournalColors.textSecondary,
                            fontWeight: _mood == mood
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          showCheckmark: false,
                          side: BorderSide(
                            color: _mood == mood
                                ? JournalColors.primary
                                : JournalColors.border,
                          ),
                          selected: _mood == mood,
                          selectedColor: JournalColors.accent,
                          backgroundColor: JournalColors.surface,
                          onSelected: !_editing || _busy
                              ? null
                              : (_) => setState(() => _mood = mood),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Lĩnh vực liên quan', style: _title),
                  const SizedBox(height: 4),
                  const Text('Có thể chọn nhiều lĩnh vực', style: _caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final domain in _domains)
                        FilterChip(
                          avatar: Icon(
                            domain == _domains[0]
                                ? Icons.directions_run_rounded
                                : domain == _domains[1]
                                ? Icons.back_hand_outlined
                                : domain == _domains[2]
                                ? Icons.chat_bubble_outline_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: _selected.contains(domain)
                                ? JournalColors.primaryDark
                                : JournalColors.primary,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          side: BorderSide(
                            color: _selected.contains(domain)
                                ? JournalColors.primary
                                : JournalColors.border,
                          ),
                          label: Text(domain),
                          labelStyle: _body.copyWith(
                            color: _selected.contains(domain)
                                ? JournalColors.primaryDark
                                : JournalColors.textPrimary,
                            fontWeight: _selected.contains(domain)
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          selected: _selected.contains(domain),
                          selectedColor: JournalColors.primarySoft,
                          backgroundColor: JournalColors.surface,
                          showCheckmark: false,
                          onSelected: !_editing || _busy
                              ? null
                              : (selected) => setState(() {
                                  selected
                                      ? _selected.add(domain)
                                      : _selected.remove(domain);
                                }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Ngày ghi nhận', style: _title),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: JournalColors.textPrimary,
                      side: const BorderSide(color: JournalColors.border),
                    ),
                    onPressed: !_editing || _busy
                        ? null
                        : () async {
                            final picked = await showAppDatePicker(
                              context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              helpText: 'Chọn ngày nhật ký',
                            );
                            if (picked != null && mounted) {
                              setState(() => _date = picked);
                            }
                          },
                    icon: const Icon(
                      Icons.calendar_today_outlined,
                      color: JournalColors.primary,
                    ),
                    label: Text(_dateLabel(_date)),
                  ),
                ],
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bookmark_added_outlined),
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: JournalColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_busy ? 'Đang lưu…' : 'Lưu nhật ký'),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: JournalColors.textSecondary,
                ),
                child: const Text('Hủy'),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: JournalColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: JournalColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: JournalColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: _caption.copyWith(
        color: JournalColors.primaryDark,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

/// Ảnh base64 của nhật ký cũ.
class _Photo extends StatelessWidget {
  const _Photo({required this.photo});
  final String photo;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.memory(
      base64Decode(photo),
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox(
        height: 80,
        child: Center(child: Text('Không tải được ảnh')),
      ),
    ),
  );
}
