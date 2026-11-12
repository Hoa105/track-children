import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../home/background/local_background_image.dart';
import '../home/home_ui_icon.dart';
import 'photobooth_session.dart';

class PhotoBoothPhotoSelection extends StatelessWidget {
  const PhotoBoothPhotoSelection({
    required this.session,
    required this.selectedSlot,
    required this.busy,
    required this.onMode,
    required this.onSlot,
    required this.onPhoto,
    required this.onAddMore,
    required this.onContinue,
    this.error,
    super.key,
  });

  final PhotoBoothSession session;
  final int selectedSlot;
  final bool busy;
  final String? error;
  final ValueChanged<PhotoBoothMode> onMode;
  final ValueChanged<int> onSlot;
  final ValueChanged<int> onPhoto;
  final VoidCallback onAddMore;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final missing = session.mode.count - session.shots.length;
    final selected = session.selectedPhotos.length;
    return Column(
      children: [
        Padding(
          key: const ValueKey('photobooth-selected-photos'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Số ảnh',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: SegmentedButton<PhotoBoothMode>(
                        segments: [
                          for (final mode in PhotoBoothMode.values)
                            ButtonSegment(
                              value: mode,
                              label: Text(
                                '${mode.count} ảnh',
                                key: ValueKey(
                                  'photobooth-layout-${mode.count}',
                                ),
                              ),
                            ),
                        ],
                        selected: {session.mode},
                        showSelectedIcon: false,
                        onSelectionChanged: busy
                            ? null
                            : (values) => onMode(values.single),
                        style: ButtonStyle(
                          side: const WidgetStatePropertyAll(BorderSide.none),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? AppColors.primarySoft
                                : Colors.transparent,
                          ),
                          foregroundColor: const WidgetStatePropertyAll(
                            AppColors.primaryDark,
                          ),
                          minimumSize: const WidgetStatePropertyAll(
                            Size(72, 40),
                          ),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 14),
                          ),
                          textStyle: WidgetStatePropertyAll(
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: session.mode == PhotoBoothMode.two ? 168 : 336,
                  ),
                  child: Row(
                    children: [
                      for (var slot = 0; slot < session.mode.count; slot++) ...[
                        if (slot > 0) const SizedBox(width: 8),
                        Expanded(child: _slot(slot)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      missing > 0
                          ? 'Cần thêm $missing ảnh để tiếp tục'
                          : session.complete
                          ? 'Chạm một ô để thay ảnh'
                          : 'Chọn ảnh cho ô ${selectedSlot + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    liveRegion: true,
                    label: 'Đã chọn $selected trên ${session.mode.count} ảnh',
                    child: ExcludeSemantics(
                      child: Text(
                        '$selected/${session.mode.count}',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Ảnh đã chụp',
                    children: [
                      TextSpan(
                        text: '  ${session.shots.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: busy ? null : onAddMore,
                icon: const HomeUiIcon(HomeUiIconName.camera, size: 18),
                label: const Text('Chụp thêm'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              key: const ValueKey('photobooth-review-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth >= 600 ? 4 : 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: .75,
              ),
              itemCount: session.shots.length,
              itemBuilder: (_, index) => _candidate(index),
            ),
          ),
        ),
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                FilledButton(
                  key: const ValueKey('photobooth-select-continue'),
                  onPressed: busy || !session.complete ? null : onContinue,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    textStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: Text(busy ? 'Đang mở bộ ảnh…' : 'Trang trí ảnh'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _slot(int slot) {
    final active = slot == selectedSlot;
    final index = session.selectedIndices[slot];
    return Semantics(
      label:
          'Ô ảnh ${slot + 1}${index == null ? ', chưa chọn' : ', ảnh ${index + 1}'}',
      excludeSemantics: true,
      selected: active,
      button: true,
      child: Material(
        color: active ? AppColors.primarySoft : const Color(0xFFF0EDE5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('photobooth-slot-$slot'),
          onTap: busy ? null : () => onSlot(slot),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
                width: active ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: index == null
                  ? Center(
                      child: Text(
                        '${slot + 1}',
                        style: TextStyle(
                          color: active
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        _photo(session.shots[index]),
                        Positioned(
                          top: 3,
                          left: 3,
                          child: _badge('${slot + 1}'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _candidate(int index) {
    final slot = session.selectedIndices.indexOf(index);
    final selected = slot >= 0;
    return Semantics(
      label: 'Ảnh ${index + 1}${selected ? ', đang ở ô ${slot + 1}' : ''}',
      excludeSemantics: true,
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('photobooth-review-$index'),
          onTap: busy ? null : () => onPhoto(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _photo(session.shots[index]),
              if (selected)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary, width: 3),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: selected
                    ? _badge('${slot + 1}', selected: true)
                    : Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: .16),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, {bool selected = false}) => Container(
    alignment: Alignment.center,
    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: selected ? AppColors.primary : Colors.white,
      shape: BoxShape.circle,
    ),
    child: Text(
      label,
      style: TextStyle(
        color: selected ? Colors.white : AppColors.primaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _photo(LocalPhoto shot) => LayoutBuilder(
    builder: (context, constraints) => Image(
      image: ResizeImage.resizeIfNeeded(
        (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 600),
        null,
        localBackgroundImage(shot.path)!,
      ),
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) =>
          const Center(child: HomeUiIcon(HomeUiIconName.image)),
    ),
  );
}
