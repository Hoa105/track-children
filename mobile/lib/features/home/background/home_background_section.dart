import 'package:flutter/material.dart';

import '../../../app_colors.dart';
import '../home_ui_icon.dart';
import 'background_config.dart';
import 'default_background_resolver.dart';
import 'home_background_frame.dart';
import 'home_background_repository.dart';
import 'home_background_flow.dart';
import 'photobooth_entry_screen.dart';

/// Optional override returning an unpersisted final choice; null cancels.
/// The built-in flow owns its transaction and returns an already applied config.
typedef HomeBackgroundChooser = Future<BackgroundConfig?> Function(
  BuildContext context,
  BackgroundConfig current,
);

class HomeBackgroundSection extends StatefulWidget {
  const HomeBackgroundSection({
    required this.accountId,
    required this.childId,
    required this.role,
    required this.childGender,
    required this.isCurrentProfile,
    this.repository = const HomeBackgroundRepository(),
    this.onChangeBackground,
    this.header,
    this.profileChanges,
    this.photobooth,
    super.key,
  });

  final String? accountId;
  final String? childId;
  final String? role;
  final String? childGender;
  final HomeBackgroundRepository repository;
  final HomeBackgroundChooser? onChangeBackground;
  final Widget? header;
  final Listenable? profileChanges;
  final PhotoboothHomeLauncher? photobooth;
  final bool Function() isCurrentProfile;

  @override
  State<HomeBackgroundSection> createState() => _HomeBackgroundSectionState();
}

class _HomeBackgroundSectionState extends State<HomeBackgroundSection> {
  BackgroundConfig? _config;
  String? _error;
  bool _loading = true;
  bool _choosing = false;
  int _generation = 0;
  HomeBackgroundFlow? _flow;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeBackgroundSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.childId != widget.childId ||
        oldWidget.repository != widget.repository) {
      _flow?.cancel();
      _load();
    } else if (oldWidget.role != widget.role ||
        oldWidget.childGender != widget.childGender) {
      _flow?.cancel();
    }
  }

  @override
  void dispose() {
    _flow?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _config = null;
    _error = null;
    _loading = true;
    _choosing = false;
    final accountId = widget.accountId;
    final childId = widget.childId;
    if (accountId == null || childId == null) {
      _loading = false;
      return;
    }
    try {
      final config = await widget.repository.load(
        accountId: accountId,
        childId: childId,
      );
      if (!mounted || generation != _generation || !widget.isCurrentProfile()) {
        return;
      }
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation || !widget.isCurrentProfile()) {
        return;
      }
      setState(() {
        _error = 'Chưa tải được tùy chọn ảnh nền. Đang dùng ảnh mặc định.';
        _loading = false;
      });
    }
  }

  Future<void> _changeBackground() async {
    if (_loading || _choosing) return;
    final chooser = widget.onChangeBackground;
    final accountId = widget.accountId;
    final childId = widget.childId;
    if (accountId == null || childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn hãy chọn hồ sơ bé trước khi đổi ảnh nền.'),
        ),
      );
      return;
    }
    final generation = _generation;
    final repository = widget.repository;
    setState(() => _choosing = true);
    try {
      final current = _config ?? BackgroundConfig(childId: childId);
      BackgroundConfig? confirmed;
      if (chooser != null) {
        confirmed = await chooser(context, current);
      } else {
        final flow = HomeBackgroundFlow(
          context: context,
          accountId: accountId,
          childId: childId,
          current: current,
          repository: repository,
          profileChanges: widget.profileChanges,
          photobooth: widget.photobooth,
          isCurrentProfile: () =>
              mounted && generation == _generation && widget.isCurrentProfile(),
        );
        _flow = flow;
        confirmed = await flow.open();
      }
      if (!mounted ||
          generation != _generation ||
          !widget.isCurrentProfile() ||
          confirmed == null) {
        return;
      }
      if (confirmed.childId != childId) throw StateError('Wrong child');
      // Production flow already committed once on Apply. Keep injected chooser
      // compatibility for callers that return an unpersisted confirmed config.
      if (chooser != null) {
        await repository.save(accountId: accountId, config: confirmed);
      }
      if (!mounted || generation != _generation || !widget.isCurrentProfile()) {
        return;
      }
      setState(() {
        _config = confirmed;
        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _generation || !widget.isCurrentProfile()) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa đổi được ảnh nền. Vui lòng thử lại.'),
        ),
      );
    } finally {
      _flow = null;
      if (mounted && generation == _generation) {
        setState(() => _choosing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = const DefaultBackgroundResolver().resolve(
      role: widget.role,
      childGender: widget.childGender,
    );
    final config = _config;
    final selected = config?.source == BackgroundSource.defaultImage
        ? defaultBackgroundManifest
              .where((a) => a.key == config?.selectedDefaultKey)
              .firstOrNull
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null && widget.header == null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: const TextStyle(fontSize: 12)),
          ),
        HomeBackgroundFrame(
          header: widget.header == null
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.header!,
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
          source: config?.source ?? BackgroundSource.defaultImage,
          assetPath: (selected ?? resolved)?.assetPath,
          finalLocalPath: config?.finalLocalPath,
          loading: _loading,
          overlay: Stack(
            children: [
              Positioned(
                top: 12,
                right: 16,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.primarySoft),
                  ),
                  elevation: 1,
                  shadowColor: const Color(0x26194C3C),
                  child: Semantics(
                    container: true,
                    label: 'Đổi ảnh nền trang chủ',
                    button: true,
                    enabled: !_loading && !_choosing,
                    onTap: _loading || _choosing ? null : _changeBackground,
                    excludeSemantics: true,
                    child: IconButton(
                      tooltip: 'Đổi ảnh nền trang chủ',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: _loading || _choosing
                          ? null
                          : _changeBackground,
                      icon: Opacity(
                        opacity: _loading || _choosing ? .45 : 1,
                        child: const HomeUiIcon(
                          HomeUiIconName.photoSparkles,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
