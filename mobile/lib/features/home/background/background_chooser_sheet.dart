import 'package:flutter/material.dart';

import '../../../app_colors.dart';
import '../home_ui_icon.dart';
import 'background_config.dart';
import 'background_draft.dart';

class BackgroundChooserSheet extends StatefulWidget {
  const BackgroundChooserSheet({
    required this.currentSource,
    required this.onSelected,
    this.errorMessage,
    this.onOpenSettings,
    super.key,
  });
  final BackgroundSource currentSource;
  final ValueChanged<BackgroundSource> onSelected;
  final String? errorMessage;
  final Future<void> Function()? onOpenSettings;

  @override
  State<BackgroundChooserSheet> createState() => _BackgroundChooserSheetState();
}

class _BackgroundChooserSheetState extends State<BackgroundChooserSheet> {
  bool _openingSettings = false;
  String? _settingsError;

  Future<void> _openSettings() async {
    if (_openingSettings) return;
    setState(() {
      _openingSettings = true;
      _settingsError = null;
    });
    try {
      await widget.onOpenSettings?.call();
    } on BackgroundFlowCancelled {
      /* Profile change already closes this sheet. */
    } on BackgroundImageException catch (error) {
      if (mounted) setState(() => _settingsError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _settingsError =
              'Bạn hãy mở Cài đặt của thiết bị và cấp quyền Ảnh rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

  String? get errorMessage => _settingsError ?? widget.errorMessage;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 16),
            child: Text(
              'Đổi ảnh nền',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  key: const ValueKey('background-source-error'),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.onOpenSettings != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _openingSettings ? null : _openSettings,
                child: Text(
                  _openingSettings ? 'Đang mở Cài đặt…' : 'Mở Cài đặt',
                ),
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final option in const [
                    (
                      BackgroundSource.defaultImage,
                      HomeUiIconName.defaultCollection,
                      'Ảnh mặc định',
                      'Dùng ảnh có sẵn theo hồ sơ bé.',
                    ),
                    (
                      BackgroundSource.gallery,
                      HomeUiIconName.image,
                      'Ảnh từ thư viện',
                      'Chọn ảnh trên điện thoại.',
                    ),
                    (
                      BackgroundSource.photobooth,
                      HomeUiIconName.camera,
                      'Chụp Photobooth',
                      'Chụp nhiều ảnh, tạo ảnh ghép.',
                    ),
                  ])
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      minLeadingWidth: 24,
                      leading: HomeUiIcon(option.$2),
                      title: Text(
                        option.$3,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(option.$4),
                      trailing: widget.currentSource == option.$1
                          ? const HomeUiIcon(
                              HomeUiIconName.check,
                              semanticLabel: 'Đang áp dụng',
                            )
                          : null,
                      onTap: _openingSettings
                          ? null
                          : () => widget.onSelected(option.$1),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
