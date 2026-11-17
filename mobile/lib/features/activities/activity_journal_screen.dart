import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
import '../../models/activity.dart';
import '../../models/video_insight.dart';
import '../../services/demo_store.dart';
import '../../services/journal_media.dart';
import '../journal/video_insight_view.dart';

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

/// Journal domains (journal_screen.dart) for each activity group.
const _groupDomains = <String, String>{
  'g0': 'Vận động thô',
  'g1': 'Vận động tinh',
  'g2': 'Ngôn ngữ',
  'g3': 'Xã hội – Cảm xúc',
};
const maxVideoMb = 150;
const pollInterval = Duration(seconds: 4);

/// "Thêm nhật ký" from an activity: note + video, optionally sent to AI for
/// observations and suggestions (never a pass / fail score).
class ActivityJournalScreen extends StatefulWidget {
  const ActivityJournalScreen({
    super.key,
    required this.childId,
    required this.activity,
    required this.guide,
    this.pickVideo,
  });
  final String childId;
  final ChildActivity activity;

  /// Activity instructions sent to the AI as context.
  final List<(String, String)> guide;

  /// Overrides ImagePicker in tests.
  final Future<XFile?> Function(ImageSource source)? pickVideo;

  @override
  State<ActivityJournalScreen> createState() => _ActivityJournalScreenState();
}

class _ActivityJournalScreenState extends State<ActivityJournalScreen> {
  final _note = TextEditingController();
  XFile? _video;
  String? _videoId;
  int _videoBytes = 0;
  bool _consent = false, _busy = false;
  String? _entryId;
  VideoInsight? _insight;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    _note.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file =
          await (widget.pickVideo?.call(source) ??
              ImagePicker().pickVideo(
                source: source,
                maxDuration: const Duration(seconds: 90),
              ));
      if (file == null) return;
      final size = await file.length();
      if (size > maxVideoMb * 1024 * 1024) {
        _message(
          'Video lớn hơn $maxVideoMb MB. Ba mẹ cắt ngắn rồi chọn lại nhé.',
        );
        return;
      }
      if (mounted) {
        setState(() {
          _video = file;
          _videoId = null;
          _videoBytes = size;
        });
      }
    } catch (_) {
      _message(
        'Không mở được video. Vui lòng kiểm tra quyền truy cập và thử lại.',
      );
    }
  }

  /// Copies the video into the app folder so it is kept with the diary and
  /// uploaded to the backend (also later, when offline now).
  Future<List<Map<String, dynamic>>> _keepVideo() async {
    final video = _video;
    if (video == null) return [];
    final id = _videoId ??= DemoStore.newMediaId();
    final path = await JournalMediaFiles.instance.keep(video, id);
    return [
      {'id': id, 'type': 'video', 'path': path, 'uploaded': false},
    ];
  }

  Map<String, dynamic> _entry(List<Map<String, dynamic>> media) {
    final note = _note.text.trim();
    final domain = _groupDomains[widget.activity.groupId];
    return {
      'id': _entryId ?? 'journal_${DateTime.now().microsecondsSinceEpoch}',
      'date': DateTime.now().toIso8601String(),
      'note': note.isEmpty
          ? 'Cùng bé thực hiện “${widget.activity.name}”.'
          : note,
      'mood': 'Vui vẻ',
      'domains': [?domain],
      'activityId': widget.activity.id,
      'activityName': widget.activity.name,
      'media': media,
    };
  }

  /// Save without AI (works offline).
  Future<void> _saveOnly() async {
    if (_note.text.trim().isEmpty) {
      _message('Hãy ghi lại một khoảnh khắc của bé.');
      return;
    }
    setState(() => _busy = true);
    try {
      await DemoStore.instance.saveJournalEntry(
        widget.childId,
        _entry(await _keepVideo()),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _message('Chưa lưu được nhật ký. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() async {
    final video = _video;
    final remote = DemoStore.videoInsightRemote;
    if (video == null || !_consent) return;
    setState(() => _busy = true);
    try {
      final account = remote == null
          ? null
          : await DemoStore.instance.linkedAccount(widget.childId);
      if (remote == null || account == null) {
        _message(
          'Cần kết nối máy chủ để AI nhận xét. Ba mẹ vẫn có thể lưu nhật ký.',
        );
        return;
      }
      final insight = await remote.submit(
        account,
        video: await video.readAsBytes(),
        filename: video.name,
        activity: widget.activity,
        guide: widget.guide,
        note: _note.text.trim(),
      );
      final entry = {
        ..._entry(await _keepVideo()),
        'insight': insight.toJson(),
      };
      await DemoStore.instance.saveJournalEntry(widget.childId, entry);
      if (!mounted) return;
      setState(() {
        _entryId = entry['id'] as String;
        _insight = insight;
      });
      _startPolling();
    } on ApiException catch (e) {
      _message(
        e.statusCode == 0
            ? 'Không kết nối được máy chủ. Vui lòng thử lại.'
            : e.message,
      );
    } catch (_) {
      _message('Chưa gửi được video. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startPolling() {
    _poll?.cancel();
    if (_insight?.finished ?? true) return;
    var attempts = 0;
    _poll = Timer.periodic(pollInterval, (timer) async {
      // ~5 phút; sau đó ba mẹ xem lại trong mục Nhật ký
      if (++attempts > 75) {
        timer.cancel();
        return;
      }
      try {
        final insight = await DemoStore.instance.refreshJournalInsight(
          widget.childId,
          _entryId!,
        );
        if (!mounted || insight == null) return;
        setState(() => _insight = insight);
        if (insight.finished) timer.cancel();
      } catch (_) {
        // Mạng chập chờn: thử lại ở lần sau
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final insight = _insight;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Thêm nhật ký', style: _heading),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppLayout.pagePadding),
        children: [
          Text(widget.activity.name, style: _heading),
          const SizedBox(height: 4),
          Text(widget.activity.ageLabel, style: _caption),
          const SizedBox(height: 16),
          if (insight != null)
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Nhận xét của AI', style: _title),
                  const SizedBox(height: 12),
                  VideoInsightView(insight: insight),
                  const SizedBox(height: 8),
                  Text(
                    insight.finished
                        ? 'Đã lưu vào Nhật ký của bé.'
                        : 'Đã lưu vào Nhật ký. Ba mẹ có thể rời màn hình, '
                              'kết quả sẽ hiện trong Nhật ký khi xong.',
                    style: _caption,
                  ),
                ],
              ),
            )
          else ...[
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Video bé thực hiện', style: _title),
                  const SizedBox(height: 8),
                  const Text(
                    'Quay ngang người bé, thấy toàn thân (hoặc rõ hai tay với '
                    'hoạt động khéo tay), đủ sáng, tối đa 90 giây.',
                    style: _caption,
                  ),
                  const SizedBox(height: 12),
                  if (_video != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.movie_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        _video!.name,
                        style: _body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${(_videoBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                        style: _caption,
                      ),
                      trailing: IconButton(
                        tooltip: 'Bỏ video',
                        onPressed: _busy
                            ? null
                            : () => setState(() => _video = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('Quay video'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.video_library_outlined),
                        label: const Text('Chọn video'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Ghi chú của ba mẹ', style: _title),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    readOnly: _busy,
                    minLines: 3,
                    maxLines: null,
                    maxLength: 1000,
                    style: _body,
                    decoration: const InputDecoration(
                      hintText: 'Bé làm thế nào? Có điều gì ba mẹ muốn AI chú ý không?',
                      hintStyle: _caption,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Panel(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _consent,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _consent = value ?? false),
                title: const Text(
                  'Đồng ý gửi video cho AI nhận xét',
                  style: _title,
                ),
                subtitle: const Text(
                  'Một số khung hình của video được gửi tới dịch vụ AI bên '
                  'ngoài (Google Gemini) để phân tích. Máy chủ của ứng dụng xóa '
                  'bản gửi cho AI ngay sau khi phân tích. Video vẫn được lưu '
                  'trong Nhật ký của bé cho tới khi ba mẹ xóa nhật ký.',
                  style: _caption,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy || _video == null || !_consent ? null : _analyze,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              label: Text(_busy ? 'Đang gửi video…' : 'Gửi cho AI nhận xét'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _saveOnly,
              child: const Text('Chỉ lưu nhật ký, không cần AI'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  // Material (không phải Container có màu) để ListTile vẽ được hiệu ứng chạm
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}
