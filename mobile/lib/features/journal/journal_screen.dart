import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
import '../../services/demo_store.dart';

const _heading = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
);
const _title = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: AppColors.textPrimary,
);
const _body = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: AppColors.textPrimary,
);
const _caption = TextStyle(
  fontSize: 12,
  height: 1.5,
  color: AppColors.textSecondary,
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
      final entries = DemoStore.instance.journalEntries(widget.childId).where((
        entry,
      ) {
        final date = DateTime.parse(entry['date'] as String);
        return _range == null ||
            (!date.isBefore(_range!.start) &&
                date.isBefore(_range!.end.add(const Duration(days: 1))));
      }).toList();
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Nhật ký', style: _heading),
          actions: [
            IconButton(
              tooltip: 'Lọc theo thời gian',
              onPressed: _filter,
              icon: const Icon(Icons.date_range_outlined),
            ),
          ],
        ),
        floatingActionButton: child == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _open(),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Viết nhật ký'),
              ),
        body: child == null
            ? const Center(child: Text('Chọn hồ sơ bé để xem nhật ký.'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.pagePadding,
                  8,
                  AppLayout.pagePadding,
                  100,
                ),
                children: [
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
                            Icons.auto_stories_outlined,
                            size: 48,
                            color: AppColors.primary,
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
                    Padding(
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
                                  color: AppColors.primary,
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
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                            if (entry['photo'] != null) ...[
                              const SizedBox(height: 12),
                              _Photo(
                                bytes: base64Decode(entry['photo'] as String),
                              ),
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
                                for (final domain
                                    in entry['domains'] as List? ?? [])
                                  _Tag(label: domain.toString()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
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
  Uint8List? _photo;
  bool _editing = false, _busy = false;
  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _editing = entry == null;
    _note = TextEditingController(text: entry?['note'] as String? ?? '');
    _date = entry == null
        ? DateTime.now()
        : DateTime.parse(entry['date'] as String);
    _mood = entry?['mood'] as String? ?? _moods.first;
    _selected = Set<String>.from(entry?['domains'] as List? ?? []);
    if (entry?['photo'] != null) {
      _photo = base64Decode(entry!['photo'] as String);
    }
  }

  @override
  void dispose() {
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
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      _error('Không mở được ảnh. Vui lòng kiểm tra quyền truy cập và thử lại.');
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await DemoStore.instance.saveJournalEntry(widget.childId, {
        'id':
            widget.entry?['id'] ??
            'journal_${DateTime.now().microsecondsSinceEpoch}',
        'date': _date.toIso8601String(),
        'note': _note.text.trim(),
        'mood': _mood,
        'domains': _selected.toList(),
        'photo': _photo == null ? null : base64Encode(_photo!),
      });
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
        title: const Text('Xóa nhật ký?'),
        content: const Text('Nhật ký này sẽ bị xóa và không thể khôi phục.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: Text(
        widget.entry == null
            ? 'Viết nhật ký'
            : _editing
            ? 'Sửa nhật ký'
            : 'Chi tiết nhật ký',
        style: _heading,
      ),
      actions: [
        if (widget.entry != null && !_editing) ...[
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
                        colors: [AppColors.primaryDark, AppColors.primary],
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
                          color: Color(0xFFF0DFC3),
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
                            color: Colors.white.withValues(alpha: .85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text('Khoảnh khắc của bé', style: _title),
                const SizedBox(height: 12),
                if (_photo == null && _editing)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: AppColors.primary,
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
                if (_photo != null) ...[
                  _Photo(bytes: _photo!),
                  if (_editing)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _photo = null),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Bỏ ảnh'),
                      ),
                    ),
                ],
                if (_editing) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Chụp ảnh'),
                      ),
                      OutlinedButton.icon(
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
                  decoration: const InputDecoration(
                    hintText: 'Bé đã khám phá điều gì mới?\nMột cử chỉ, một tiếng cười hay một bước tiến nhỏ…',
                    hintStyle: _caption,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: EdgeInsets.all(16),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                              ? AppColors.primaryDark
                              : AppColors.textSecondary,
                        ),
                        label: Text(mood),
                        labelStyle: _body.copyWith(
                          color: _mood == mood
                              ? AppColors.primaryDark
                              : AppColors.textSecondary,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        showCheckmark: false,
                        side: BorderSide(
                          color: _mood == mood
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        selected: _mood == mood,
                        selectedColor: AppColors.primarySoft,
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
                          color: AppColors.primary,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        side: BorderSide(
                          color: _selected.contains(domain)
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        label: Text(domain),
                        selected: _selected.contains(domain),
                        selectedColor: AppColors.primarySoft,
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
                  onPressed: !_editing || _busy
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null && mounted) {
                            setState(() => _date = picked);
                          }
                        },
                  icon: const Icon(Icons.calendar_today_outlined),
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
                backgroundColor: AppColors.primary,
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
              child: const Text('Hủy'),
            ),
          ],
          const SizedBox(height: 24),
        ],
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
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.border),
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
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label, style: _caption.copyWith(color: AppColors.primaryDark)),
  );
}

class _Photo extends StatelessWidget {
  const _Photo({required this.bytes});
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.memory(
      bytes,
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
