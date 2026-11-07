import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../app_colors.dart';

/// Shared route guard so Back exits fullscreen before leaving an assessment.
abstract final class AssessmentVideoPlayback {
  static final fullscreen = ValueNotifier(false);
  static int _revision = 0;
  static void setFullscreen(bool value) {
    final revision = ++_revision;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (revision == _revision) fullscreen.value = value;
      });
    } else {
      fullscreen.value = value;
    }
  }
}

/// Keeps the player's mobile OverlayPortal inside the scroll viewport.
/// The question screen expands this viewport to the screen during fullscreen.
class AssessmentVideoViewport extends StatefulWidget {
  const AssessmentVideoViewport({super.key, required this.child});
  final Widget child;

  @override
  State<AssessmentVideoViewport> createState() =>
      _AssessmentVideoViewportState();
}

class _AssessmentVideoViewportState extends State<AssessmentVideoViewport> {
  late final entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(AssessmentVideoViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    entry.markNeedsBuild();
  }

  @override
  void dispose() {
    entry.remove();
    entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ClipRect(child: Overlay(initialEntries: [entry]));
}

/// Lazy inline player: history lists do not allocate a WebView per question.
class AssessmentVideoFrame extends StatefulWidget {
  const AssessmentVideoFrame({
    super.key,
    required this.videoId,
    this.caption,
    this.semanticLabel,
    this.playerBuilder,
  });
  final String videoId;
  final String? caption, semanticLabel;
  @visibleForTesting
  final Widget Function(String videoId)? playerBuilder;
  @override
  State<AssessmentVideoFrame> createState() => _AssessmentVideoFrameState();
}

class _AssessmentVideoFrameState extends State<AssessmentVideoFrame> {
  bool playing = false;
  int retry = 0;
  String get id => widget.videoId.trim();
  bool get valid => RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id);
  @override
  void didUpdateWidget(AssessmentVideoFrame old) {
    super.didUpdateWidget(old);
    if (old.videoId != widget.videoId) {
      playing = false;
      retry = 0;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text(
          'Video hướng dẫn',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = math.max(220.0, width * 9 / 16);
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              key: const ValueKey('assessment-video-surface'),
              width: double.infinity,
              height: height,
              child: ColoredBox(
                color: const Color(0xFF15221D),
                child: !valid
                    ? _VideoError(
                        message: 'Video chưa có thông tin hợp lệ. Bạn vẫn có thể đọc hướng dẫn và trả lời.',
                      )
                    : playing
                    ? widget.playerBuilder?.call(id) ??
                          _InlineYoutubePlayer(
                            key: ValueKey('$id-$retry'),
                            videoId: id,
                            aspectRatio: width / height,
                            onRetry: () => setState(() => retry++),
                          )
                    : _preview(),
              ),
            ),
          );
        },
      ),
      if (!playing && valid)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Chạm nút phát để xem ngay trong app.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      if (widget.caption?.trim().isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            widget.caption!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
    ],
  );
  Widget _preview() => Semantics(
    button: true,
    label: widget.semanticLabel ?? 'Phát video hướng dẫn',
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
        const ColoredBox(color: Color(0x30000000)),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => playing = true),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 76,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _InlineYoutubePlayer extends StatefulWidget {
  const _InlineYoutubePlayer({
    super.key,
    required this.videoId,
    required this.aspectRatio,
    required this.onRetry,
  });
  final String videoId;
  final double aspectRatio;
  final VoidCallback onRetry;
  @override
  State<_InlineYoutubePlayer> createState() => _InlineYoutubePlayerState();
}

class _InlineYoutubePlayerState extends State<_InlineYoutubePlayer>
    with WidgetsBindingObserver {
  static YoutubePlayerController? active;
  YoutubePlayerController? controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      final previous = active;
      if (previous != null) {
        unawaited(previous.pauseVideo().catchError((_) {}));
      }
      // Creation follows an explicit play tap; no video auto-plays on page entry.
      controller = YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          playsInline: true,
          interfaceLanguage: 'vi',
        ),
      );
      active = controller;
      controller!.setFullScreenListener(AssessmentVideoPlayback.setFullscreen);
    } catch (_) {
      controller = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(controller?.pauseVideo().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final player = controller;
    if (identical(active, player)) {
      active = null;
      AssessmentVideoPlayback.setFullscreen(false);
    }
    if (player != null) {
      unawaited(player.close().catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    if (player == null) return _VideoError(onRetry: widget.onRetry);
    return YoutubeValueBuilder(
      controller: player,
      builder: (context, value) {
        if (value.hasError) {
          if (value.fullScreenOption.enabled) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) player.exitFullScreen();
            });
          }
          return _VideoError(onRetry: widget.onRetry);
        }
        return YoutubePlayer(
          controller: player,
          aspectRatio: widget.aspectRatio,
          autoFullScreen: false,
          enableFullScreenOnVerticalDrag: false,
          backgroundColor: const Color(0xFF15221D),
        );
      },
    );
  }
}

class _VideoError extends StatelessWidget {
  const _VideoError({
    this.message = 'Chưa phát được video. Kiểm tra kết nối rồi thử lại; bạn vẫn có thể trả lời câu hỏi.',
    this.onRetry,
  });
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white70,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.white,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Thử lại video'),
            ),
          ],
        ],
      ),
    ),
  );
}
