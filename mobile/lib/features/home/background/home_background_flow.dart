import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app_colors.dart';
import 'background_chooser_sheet.dart';
import 'background_config.dart';
import 'background_crop_state.dart';
import 'background_draft.dart';
import 'background_image_service.dart';
import 'background_picker_service.dart';
import 'crop_background_screen.dart';
import 'home_background_repository.dart';
import 'photobooth_entry_screen.dart';

/// Owns one pending flow. The applied Home config is never used as a draft.
class HomeBackgroundFlow {
  HomeBackgroundFlow({
    required this.context,
    required this.accountId,
    required this.childId,
    required this.current,
    required this.isCurrentProfile,
    required this.repository,
    this.profileChanges,
    BackgroundPickerService? picker,
    BackgroundImageService? images,
    this.photobooth,
  }) : picker = picker ?? BackgroundPickerService(files: repository.files),
       images = images ?? BackgroundImageService(files: repository.files);

  final BuildContext context;
  final String accountId;
  final String childId;
  final BackgroundConfig current;
  final HomeBackgroundRepository repository;
  final bool Function() isCurrentProfile;
  final Listenable? profileChanges;
  final BackgroundPickerService picker;
  final BackgroundImageService images;
  final PhotoboothHomeLauncher? photobooth;
  final _routes = <Route<dynamic>>{};
  static bool _active = false;
  bool _closeScheduled = false;
  bool _cancelled = false;
  DialogRoute<void>? _openingRoute;
  String? _selectionError;
  bool _selectionSettings = false;

  bool get _valid => !_cancelled && context.mounted && isCurrentProfile();
  void cancel() {
    _cancelled = true;
    _profileChanged();
  }

  void _check() {
    if (!_valid) throw const BackgroundFlowCancelled();
  }

  void _profileChanged() {
    if (_valid) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (!_closeScheduled) {
        _closeScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _closeScheduled = false;
          _profileChanged();
        });
      }
      return;
    }
    for (final route in _routes.toList().reversed) {
      if (route.isActive) route.navigator?.removeRoute(route);
    }
  }

  Widget _track(BuildContext pageContext, Widget child) {
    final route = ModalRoute.of(pageContext);
    if (route != null) _routes.add(route);
    return child;
  }

  Future<T?> _push<T>(String name, Widget page) async {
    _check();
    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    final route = MaterialPageRoute<T>(
      settings: RouteSettings(name: name),
      builder: (_) => page,
    );
    _routes.add(route);
    try {
      final result = await Navigator.of(context).push(route);
      await route.completed;
      return result;
    } finally {
      _routes.remove(route);
    }
  }

  void _message(String message, {bool canOpenSettings = false}) {
    _selectionError = message;
    _selectionSettings = canOpenSettings;
  }

  void _showOpening() {
    _check();
    if (_openingRoute != null) return;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: HomeColors.surface,
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: HomeColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Đang mở ảnh…',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: HomeColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _openingRoute = route;
    _routes.add(route);
    unawaited(Navigator.of(context).push<void>(route));
  }

  void _hideOpening() {
    final route = _openingRoute;
    if (route == null) return;
    _openingRoute = null;
    if (route.isActive) route.navigator?.removeRoute(route);
    _routes.remove(route);
  }

  Future<void> _showFailure(String message) async {
    if (!_valid || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (page) => _track(
        page,
        AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: HomeColors.surface,
          title: const Text(
            'Chưa đổi được ảnh nền',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: HomeColors.ink,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: HomeColors.reminderCta,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(page),
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  Future<BackgroundConfig?> _applyDefault() async {
    _check();
    var busy = false;
    String? error;
    return showDialog<BackgroundConfig>(
      context: context,
      builder: (page) => _track(
        page,
        StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !busy,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: HomeColors.surface,
              title: const Text(
                'Dùng ảnh mặc định?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: HomeColors.ink,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ảnh nền sẽ được chọn theo vai trò người chăm sóc.',
                    style: TextStyle(
                      fontSize: 14,
                      color: HomeColors.reminderCta,
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    foregroundColor: HomeColors.ink,
                  ),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (busy) return;
                          setDialogState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            _check();
                            final config = await repository.apply(
                              accountId: accountId,
                              draft: BackgroundDraft(
                                childId: childId,
                                source: BackgroundSource.defaultImage,
                              ),
                              isCurrentProfile: () => _valid,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, config);
                            }
                          } on BackgroundFlowCancelled {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (_) {
                            if (dialogContext.mounted) {
                              setDialogState(
                                () => error = 'Chưa lưu được ảnh nền. Ảnh cũ vẫn được giữ, bạn hãy thử lại.',
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => busy = false);
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Áp dụng'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<BackgroundConfig?> _custom(
    String input,
    BackgroundSource source,
  ) async {
    DecodedBackgroundImage? decoded;
    BackgroundCropState? crop;
    String? croppedPath;
    var prepared = input;
    try {
      _check();
      _showOpening();
      if (source == BackgroundSource.photobooth) {
        prepared = await images.preparePhotobooth(input);
      }
      _check();
      decoded = await images.decode(prepared);
      _check();
      images.validateSize(decoded);
      crop = BackgroundCropState(sourceSize: decoded.naturalSize);
      _hideOpening();
      final result = await _push<BackgroundConfig>(
        '/home/background/crop',
        CropBackgroundScreen(
          image: decoded,
          crop: crop,
          onApply: () async {
            _check();
            await repository.files.removePending(croppedPath);
            final exported = await images.export(
              prepared,
              crop!.normalizedRect,
            );
            if (!_valid) {
              await repository.files.removePending(exported);
              throw const BackgroundFlowCancelled();
            }
            croppedPath = exported;
            return repository.apply(
              accountId: accountId,
              draft: BackgroundDraft(
                childId: childId,
                source: source,
                croppedPath: exported,
              ),
              isCurrentProfile: () => _valid,
            );
          },
        ),
      );
      _check();
      return result;
    } finally {
      _hideOpening();
      crop?.dispose();
      decoded?.dispose();
      await repository.files.removePending(input);
      if (prepared != input) await repository.files.removePending(prepared);
      await repository.files.removePending(croppedPath);
    }
  }

  Future<BackgroundConfig?> open() async {
    if (_active || !_valid) return null;
    _active = true;
    profileChanges?.addListener(_profileChanged);
    try {
      if (!kIsWeb) {
        final recovered = await picker.takeRecovered(
          accountId: accountId,
          childId: childId,
        );
        if (recovered != null) {
          var consumed = false;
          try {
            _check();
            if (!context.mounted) return null;
            final resume = await showDialog<bool>(
              context: context,
              builder: (page) => _track(
                page,
                AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: HomeColors.surface,
                  title: const Text(
                    'Tiếp tục chỉnh ảnh?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: HomeColors.ink,
                    ),
                  ),
                  content: const Text(
                    'Bạn còn một ảnh nền chưa hoàn tất.',
                    style: TextStyle(
                      fontSize: 14,
                      color: HomeColors.reminderCta,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(page, false),
                      style: TextButton.styleFrom(
                        foregroundColor: HomeColors.ink,
                      ),
                      child: const Text('Chọn ảnh khác'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(page, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: HomeColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Tiếp tục'),
                    ),
                  ],
                ),
              ),
            );
            _check();
            if (resume == true) {
              consumed = true;
              return await _custom(recovered, BackgroundSource.gallery);
            }
          } finally {
            if (!consumed) await repository.files.removePending(recovered);
          }
        }
      }
      while (_valid) {
        if (!context.mounted) return null;
        final source = await showModalBottomSheet<BackgroundSource>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: HomeColors.background,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (sheet) => _track(
            sheet,
            BackgroundChooserSheet(
              currentSource: current.source,
              errorMessage: _selectionError,
              onOpenSettings: !_selectionSettings
                  ? null
                  : () async {
                      _check();
                      await picker.openSettings();
                      _check();
                    },
              onSelected: (source) => Navigator.pop(sheet, source),
            ),
          ),
        );
        _check();
        if (source == null) return null;
        _selectionError = null;
        _selectionSettings = false;
        if (!context.mounted) return null;
        ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
        if (source == BackgroundSource.defaultImage) {
          return await _applyDefault();
        }
        if (kIsWeb) {
          _message('Bạn hãy dùng ứng dụng Android hoặc iOS để chọn ảnh nền.');
          continue;
        }
        try {
          if (source == BackgroundSource.gallery) {
            _showOpening();
            try {
              final input = await picker.pick(
                accountId: accountId,
                childId: childId,
              );
              if (input == null) return null;
              // _custom owns cleanup even when the account changed in the picker.
              return await _custom(input, source);
            } finally {
              _hideOpening();
            }
          }
          final launch = photobooth;
          if (launch == null) {
            final applied = await _push<BackgroundConfig>(
              '/home/background/photobooth',
              PhotoboothEntryScreen(
                accountId: accountId,
                childId: childId,
                onUseHome: (path) async {
                  _check();
                  final owned = await repository.files.keepInput(path);
                  return _custom(owned, BackgroundSource.photobooth);
                },
              ),
            );
            if (applied != null) return applied;
            continue;
          }
          if (!context.mounted) return null;
          final input = await launch(context, childId);
          _check();
          if (input == null) return null;
          if (input.childId != childId) throw const BackgroundFlowCancelled();
          final owned = await repository.files.keepInput(input.localPath);
          return await _custom(owned, BackgroundSource.photobooth);
        } on BackgroundImageException catch (error) {
          _message(error.message, canOpenSettings: error.canOpenSettings);
        }
      }
    } on BackgroundFlowCancelled {
      return null;
    } on BackgroundImageException catch (error) {
      await _showFailure(error.message);
    } catch (_) {
      await _showFailure('Bạn hãy thử chọn ảnh nền lại.');
    } finally {
      _hideOpening();
      profileChanges?.removeListener(_profileChanged);
      _active = false;
      _routes.clear();
    }
    return null;
  }
}
