import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'photobooth_text.dart';

class PhotoBoothTextInput {
  const PhotoBoothTextInput(this.color, this.backgroundColor, this.fontSize);
  final int color, backgroundColor;
  final double fontSize;
}

/// Compact styling tools for the caption selected on the photo.
class PhotoBoothTextComposer extends StatefulWidget {
  const PhotoBoothTextComposer({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.onChangeStart,
    this.onChangeEnd,
    super.key,
  });
  final PhotoBoothText? value;
  final ValueChanged<PhotoBoothTextInput> onChanged;
  final bool enabled;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  static const colors = <int, String>{
    0xFFFFFFFF: 'Trắng',
    0xFF23332E: 'Đen',
    0xFF8C9290: 'Xám',
    0xFF8D6346: 'Nâu',
    0xFFE34F4F: 'Đỏ',
    0xFFE67D3C: 'Cam',
    0xFFF3B548: 'Vàng',
    0xFFEFDCC0: 'Be',
    0xFF286B52: 'Xanh lá',
    0xFFA8DBC3: 'Xanh bạc hà',
    0xFF239B97: 'Xanh ngọc',
    0xFF92CEF4: 'Xanh da trời',
    0xFF317EC1: 'Xanh dương',
    0xFF243C70: 'Xanh đậm',
    0xFF9B5BC4: 'Tím',
    0xFFE96392: 'Hồng',
  };

  @override
  State<PhotoBoothTextComposer> createState() => _PhotoBoothTextComposerState();
}

class _PhotoBoothTextComposerState extends State<PhotoBoothTextComposer> {
  bool _background = false;
  bool get _enabled => widget.enabled && widget.value != null;
  final _paletteScroll = ScrollController();
  Widget? _palette;
  (bool, int, bool)? _paletteKey;
  ColorScheme? _paletteColors;

  @override
  void dispose() {
    _paletteScroll.dispose();
    super.dispose();
  }

  void _change({int? color, int? background, double? size}) {
    final text = widget.value;
    if (!_enabled || text == null) return;
    widget.onChanged(
      PhotoBoothTextInput(
        color ?? text.color,
        background ?? text.backgroundColor,
        size ?? text.fontSize,
      ),
    );
  }

  Widget _swatch(int color, String name) {
    final selected =
        widget.value != null &&
        (_background ? widget.value!.backgroundColor : widget.value!.color) ==
            color;
    final target = _background ? 'background-color' : 'color';
    final label = '${_background ? 'Màu nền' : 'Màu chữ'}: $name';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: InkWell(
            key: ValueKey('photobooth-text-$target-$color'),
            onTap: !_enabled
                ? null
                : () => _background
                      ? _change(background: color)
                      : _change(color: color),
            customBorder: const CircleBorder(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color == 0 ? null : Color(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: color == 0
                  ? const Icon(Icons.format_color_reset_rounded, size: 22)
                  : selected
                  ? Icon(
                      Icons.check_rounded,
                      color: Color(color).computeLuminance() > .4
                          ? Colors.black87
                          : Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _paletteWidget() {
    final color = _background
        ? widget.value?.backgroundColor
        : widget.value?.color;
    final key = (_background, color ?? 0, _enabled);
    final colors = Theme.of(context).colorScheme;
    if (_paletteKey == key && _paletteColors == colors && _palette != null) {
      return _palette!;
    }
    _paletteKey = key;
    _paletteColors = colors;
    return _palette = SingleChildScrollView(
      key: const ValueKey('photobooth-text-palette'),
      controller: _paletteScroll,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (_background) _swatch(0, 'Không nền'),
          for (final entry in PhotoBoothTextComposer.colors.entries)
            _swatch(entry.key, entry.value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('photobooth-text-panel'),
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final background in [false, true])
              Expanded(
                child: TextButton(
                  key: ValueKey(
                    background
                        ? 'photobooth-text-background-tool'
                        : 'photobooth-text-color-tool',
                  ),
                  onPressed: !widget.enabled
                      ? null
                      : () {
                          setState(() => _background = background);
                          if (_paletteScroll.hasClients) {
                            _paletteScroll.jumpTo(0);
                          }
                        },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    foregroundColor: _background == background
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  child: Text(
                    background ? 'Màu nền' : 'Màu chữ',
                    style: TextStyle(
                      fontWeight: _background == background
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        _paletteWidget(),
        Row(
          children: [
            const Text('Cỡ chữ', style: TextStyle(fontWeight: FontWeight.w700)),
            Expanded(
              child: Slider(
                key: const ValueKey('photobooth-text-size'),
                value: (widget.value?.fontSize ?? .07).clamp(.025, .16),
                min: .025,
                max: .16,
                onChangeStart: !_enabled
                    ? null
                    : (_) => widget.onChangeStart?.call(),
                onChangeEnd: !_enabled
                    ? null
                    : (_) => widget.onChangeEnd?.call(),
                onChanged: !_enabled ? null : (value) => _change(size: value),
              ),
            ),
          ],
        ),
        if (widget.value == null)
          Text(
            'Chạm đúp vùng trống trên ảnh để nhập chữ.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    ),
  );
}

/// Editing is local until Xong. The painter underneath remains the source of
/// the displayed glyphs; a transparent native text field supplies caret,
/// selection, Vietnamese IME, copy and paste directly over those glyphs.
class PhotoBoothCaptionEditor extends StatefulWidget {
  const PhotoBoothCaptionEditor({
    required this.initial,
    required this.layouts,
    required this.canvasSize,
    required this.previewBuilder,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });
  final PhotoBoothText initial;
  final PhotoBoothTextLayoutCache layouts;
  final Size canvasSize;
  final Widget Function(PhotoBoothText text) previewBuilder;
  final ValueChanged<PhotoBoothText> onConfirm;
  final VoidCallback onCancel;

  @override
  State<PhotoBoothCaptionEditor> createState() =>
      _PhotoBoothCaptionEditorState();
}

class _PhotoBoothCaptionEditorState extends State<PhotoBoothCaptionEditor> {
  late final _input = TextEditingController(text: widget.initial.text);
  late PhotoBoothText _value = widget.initial;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _input.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Bạn hãy nhập nội dung chữ.');
      return;
    }
    widget.onConfirm(
      _value.copy(text: text).move(widget.canvasSize, layouts: widget.layouts),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('photobooth-text-editor'),
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: AspectRatio(
              aspectRatio: widget.canvasSize.aspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final shown = _value
                      .copy(
                        text: _input.text.isEmpty ? 'Nhập chữ' : _input.text,
                      )
                      .move(widget.canvasSize, layouts: widget.layouts);
                  final measured = widget.layouts.obtain(
                    shown,
                    widget.canvasSize,
                  );
                  final font =
                      (measured.fill.text! as TextSpan).style!.fontSize!;
                  final height = measured.fill.height;
                  final extent = measured.size;
                  final scale = constraints.maxWidth / widget.canvasSize.width;
                  final center = Offset(
                    shown.x * constraints.maxWidth,
                    shown.y * constraints.maxHeight,
                  );
                  final width = constraints.maxWidth * .86;
                  return Stack(
                    key: const ValueKey('photobooth-text-edit-canvas'),
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: widget.previewBuilder(shown),
                        ),
                      ),
                      Positioned(
                        left: center.dx - extent.width * scale / 2,
                        top: center.dy - extent.height * scale / 2,
                        width: extent.width * scale,
                        height: extent.height * scale,
                        child: Transform.rotate(
                          key: const ValueKey(
                            'photobooth-text-selection-rotation',
                          ),
                          angle: shown.rotation,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: center.dx - width / 2,
                        top: center.dy - height * scale / 2,
                        width: width,
                        child: Transform.rotate(
                          key: const ValueKey('photobooth-text-input-rotation'),
                          angle: shown.rotation,
                          child: MediaQuery.withNoTextScaling(
                            child: TextField(
                              key: const ValueKey('photobooth-text-input'),
                              controller: _input,
                              autofocus: true,
                              minLines: 1,
                              maxLines: null,
                              maxLength: 120,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.ltr,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: font * scale,
                                height: 1.18,
                                color: Colors.transparent,
                              ),
                              cursorColor: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              cursorWidth: 1,
                              scrollPadding: EdgeInsets.zero,
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                counterText: '',
                              ),
                              inputFormatters: [
                                TextInputFormatter.withFunction(
                                  (previous, next) =>
                                      next.text.split('\n').length > 3
                                      ? previous
                                      : next,
                                ),
                              ],
                              onChanged: (text) => setState(() {
                                _error = null;
                                _value = _value
                                    .copy(text: text)
                                    .move(
                                      widget.canvasSize,
                                      layouts: widget.layouts,
                                    );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            TextButton(
              key: const ValueKey('photobooth-text-cancel'),
              onPressed: widget.onCancel,
              child: const Text('Hủy'),
            ),
            Expanded(
              child: Text(
                'Chỉnh nội dung trên ảnh',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            FilledButton(
              key: const ValueKey('photobooth-text-confirm'),
              onPressed: _confirm,
              child: const Text('Xong'),
            ),
          ],
        ),
      ),
    ],
  );
}
