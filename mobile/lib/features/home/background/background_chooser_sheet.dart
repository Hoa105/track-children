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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 4, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Đổi ảnh nền',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: HomeColors.ink,
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Đóng',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Đóng',
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: HomeColors.ink,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  key: const ValueKey('background-source-error'),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (widget.onOpenSettings != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openingSettings ? null : _openSettings,
                  icon: const Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: HomeColors.primary,
                  ),
                  label: Text(
                    _openingSettings ? 'Đang mở Cài đặt…' : 'Mở Cài đặt',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: HomeColors.primary,
                    ),
                  ),
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
                  ]) ...[
                    _buildOptionTile(
                      source: option.$1,
                      icon: option.$2,
                      title: option.$3,
                      description: option.$4,
                      isSelected: widget.currentSource == option.$1,
                      onTap: _openingSettings
                          ? null
                          : () => widget.onSelected(option.$1),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildOptionTile({
    required BackgroundSource source,
    required HomeUiIconName icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback? onTap,
  }) => ListTile(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: isSelected ? HomeColors.primary : const Color(0xFFE2EBE0),
        width: isSelected ? 1.8 : 1,
      ),
    ),
    tileColor: isSelected
        ? HomeColors.reminderBackground.withValues(alpha: 0.65)
        : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    minLeadingWidth: 28,
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isSelected ? HomeColors.primary : HomeColors.iconBackground,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: HomeUiIcon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : HomeColors.primary,
        ),
      ),
    ),
    title: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14.5,
        color: HomeColors.ink,
      ),
    ),
    subtitle: Text(
      description,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: HomeColors.reminderCta,
      ),
    ),
    trailing: isSelected
        ? const HomeUiIcon(
            HomeUiIconName.check,
            color: HomeColors.primary,
            semanticLabel: 'Đang áp dụng',
          )
        : const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13,
            color: Color(0xFFA0B29E),
          ),
    onTap: onTap,
  );
}
