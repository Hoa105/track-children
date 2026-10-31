import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';

const _caption = TextStyle(
  fontSize: 12,
  height: 1.5,
  color: AppColors.textSecondary,
);

bool _hasLocalFile(Map media) =>
    !kIsWeb &&
    media['path'] != null &&
    File(media['path'] as String).existsSync();

/// A diary photo / video (`media` item of a journal entry): the copy on this
/// device when there is one, else a time-limited link from the backend.
/// Videos open [JournalVideoScreen].
class JournalMediaTile extends StatefulWidget {
  const JournalMediaTile({
    super.key,
    required this.childId,
    required this.entryId,
    required this.media,
    this.height = 180,
  });

  final String childId, entryId;
  final Map<String, dynamic> media;
  final double height;

  @override
  State<JournalMediaTile> createState() => _JournalMediaTileState();
}

class _JournalMediaTileState extends State<JournalMediaTile> {
  Future<String?>? _url;

  bool get _video => widget.media['type'] == 'video';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(JournalMediaTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media['id'] != widget.media['id']) _load();
  }

  void _load() {
    _url = _video || _hasLocalFile(widget.media)
        ? null
        : DemoStore.instance.journalMediaUrl(
            widget.childId,
            widget.entryId,
            widget.media,
          );
  }

  Widget _message(String text, [IconData icon = Icons.image_outlined]) =>
      Container(
        height: widget.height,
        color: AppColors.primarySoft.withValues(alpha: .6),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(text, style: _caption, textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _image() {
    Widget error(_, _, _) => _message('Không tải được ảnh');
    if (_hasLocalFile(widget.media)) {
      return Image.file(
        File(widget.media['path'] as String),
        height: widget.height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: error,
      );
    }
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            height: widget.height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final url = snapshot.data;
        if (url == null) {
          return _message('Cần kết nối mạng để xem ảnh', Icons.cloud_off);
        }
        return Image.network(
          url,
          height: widget.height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: error,
        );
      },
    );
  }

  Widget _videoTile() => Material(
    color: Colors.black87,
    child: InkWell(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => JournalVideoScreen(
            childId: widget.childId,
            entryId: widget.entryId,
            media: widget.media,
          ),
        ),
      ),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white),
            SizedBox(height: 4),
            Text('Xem video của bé', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rejected = widget.media['rejected'] as String?;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          _video ? _videoTile() : _image(),
          if (rejected != null || widget.media['uploaded'] != true)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rejected == null
                      ? 'Chưa tải lên máy chủ'
                      : 'Không lưu được lên máy chủ: $rejected',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Plays a diary video: from this device, else streamed with a backend link.
class JournalVideoScreen extends StatefulWidget {
  const JournalVideoScreen({
    super.key,
    required this.childId,
    required this.entryId,
    required this.media,
  });

  final String childId, entryId;
  final Map<String, dynamic> media;

  @override
  State<JournalVideoScreen> createState() => _JournalVideoScreenState();
}

class _JournalVideoScreenState extends State<JournalVideoScreen> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final VideoPlayerController controller;
      if (_hasLocalFile(widget.media)) {
        controller = VideoPlayerController.file(
          File(widget.media['path'] as String),
        );
      } else {
        final url = await DemoStore.instance.journalMediaUrl(
          widget.childId,
          widget.entryId,
          widget.media,
        );
        if (url == null) {
          if (mounted) {
            setState(() => _error = 'Cần kết nối mạng để xem video.');
          }
          return;
        }
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (_) {
      if (mounted) setState(() => _error = 'Không phát được video.');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video của bé'),
      ),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white))
            : controller == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: GestureDetector(
                      onTap: () => setState(
                        () => controller.value.isPlaying
                            ? controller.pause()
                            : controller.play(),
                      ),
                      child: VideoPlayer(controller),
                    ),
                  ),
                  VideoProgressIndicator(controller, allowScrubbing: true),
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, _) => IconButton(
                      tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát',
                      iconSize: 48,
                      color: Colors.white,
                      onPressed: () => value.isPlaying
                          ? controller.pause()
                          : controller.play(),
                      icon: Icon(
                        value.isPlaying
                            ? Icons.pause_circle_rounded
                            : Icons.play_circle_rounded,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
