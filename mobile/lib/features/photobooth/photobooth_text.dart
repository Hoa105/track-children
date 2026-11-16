import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Positions and font size are relative to the canvas, independent of dp.
class PhotoBoothText {
  const PhotoBoothText({
    required this.id,
    required this.text,
    this.color = 0xFFFFFFFF,
    this.backgroundColor = 0,
    this.fontSize = .07,
    this.x = .5,
    this.y = .5,
    this.rotation = 0,
  });

  final int id;
  final String text;
  final int color;
  final int backgroundColor;
  int get effectiveBorderColor => color;
  final double fontSize, x, y, rotation;

  PhotoBoothText copy({
    String? text,
    int? color,
    int? backgroundColor,
    double? fontSize,
  }) => PhotoBoothText(
    id: id,
    text: text ?? this.text,
    color: color ?? this.color,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    fontSize: fontSize ?? this.fontSize,
    x: x,
    y: y,
    rotation: rotation,
  );

  PhotoBoothTextLayout layout(Size canvas) {
    final maximum = Size(canvas.width * .86, canvas.height * .65);
    var pixels = canvas.shortestSide * fontSize.clamp(.025, .16);
    TextPainter painter(double size, {Paint? foreground}) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: size,
          fontWeight: FontWeight.w800,
          height: 1.18,
          color: foreground == null ? Color(color) : null,
          foreground: foreground,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout(maxWidth: maximum.width);

    var fill = painter(pixels);
    for (var attempt = 0; attempt < 8; attempt++) {
      final padding =
          math.max(1, pixels * .065) +
          (backgroundColor == 0 ? 0 : pixels * .22);
      final width =
          (fill.width + padding * 2) * math.cos(rotation).abs() +
          (fill.height + padding * 2) * math.sin(rotation).abs();
      final height =
          (fill.width + padding * 2) * math.sin(rotation).abs() +
          (fill.height + padding * 2) * math.cos(rotation).abs();
      final factor = math.min(
        1.0,
        math.min(
          maximum.height / math.max(1, fill.height),
          math.min(
            canvas.width * .94 / math.max(1, width),
            canvas.height * .94 / math.max(1, height),
          ),
        ),
      );
      if (factor >= .999) break;
      fill.dispose();
      pixels *= factor * .98;
      fill = painter(pixels);
    }
    final border = painter(
      pixels,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1, pixels * .065)
        ..color = Color(effectiveBorderColor),
    );
    return PhotoBoothTextLayout(
      fill,
      border,
      math.max(1, pixels * .065) + (backgroundColor == 0 ? 0 : pixels * .22),
      backgroundColor: backgroundColor,
      radius: pixels * .18,
    );
  }

  PhotoBoothText move(
    Size canvas, {
    double? x,
    double? y,
    double? fontSize,
    double? rotation,
    PhotoBoothTextLayoutCache? layouts,
  }) {
    final next = PhotoBoothText(
      id: id,
      text: text,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: (fontSize ?? this.fontSize).clamp(.025, .16),
      x: x ?? this.x,
      y: y ?? this.y,
      rotation: rotation ?? this.rotation,
    );
    final layout = layouts?.obtain(next, canvas) ?? next.layout(canvas);
    try {
      final dx =
          (layout.size.width * math.cos(next.rotation).abs() +
              layout.size.height * math.sin(next.rotation).abs()) /
          canvas.width /
          2;
      final dy =
          (layout.size.width * math.sin(next.rotation).abs() +
              layout.size.height * math.cos(next.rotation).abs()) /
          canvas.height /
          2;
      return PhotoBoothText(
        id: id,
        text: text,
        color: color,
        backgroundColor: backgroundColor,
        fontSize: next.fontSize,
        rotation: next.rotation,
        x: next.x.clamp(math.min(dx, .5), math.max(1 - dx, .5)),
        y: next.y.clamp(math.min(dy, .5), math.max(1 - dy, .5)),
      );
    } finally {
      if (layouts == null) layout.dispose();
    }
  }

  bool hit(Offset point, Size canvas, {PhotoBoothTextLayoutCache? layouts}) {
    final local = point - Offset(x * canvas.width, y * canvas.height);
    final dx = local.dx * math.cos(rotation) + local.dy * math.sin(rotation);
    final dy = -local.dx * math.sin(rotation) + local.dy * math.cos(rotation);
    final layout = layouts?.obtain(this, canvas) ?? this.layout(canvas);
    try {
      return dx.abs() <= layout.size.width / 2 &&
          dy.abs() <= layout.size.height / 2;
    } finally {
      if (layouts == null) layout.dispose();
    }
  }

  Map<String, Object> toJson() => {
    'id': id,
    'text': text,
    'color': color,
    'backgroundColor': backgroundColor,
    'fontSize': fontSize,
    'x': x,
    'y': y,
    'rotation': rotation,
  };
}

/// Session-owned LRU of shaped paragraphs. Position is deliberately excluded:
/// dragging reuses glyphs shared by hit testing, clamping and both paint layers.
/// Borrowed layouts belong to the cache; callers must not dispose them.
class PhotoBoothTextLayoutCache {
  PhotoBoothTextLayoutCache({this.capacity = 64}) : assert(capacity > 0);
  final int capacity;
  final _entries = <Record, PhotoBoothTextLayout>{};
  int _measurements = 0;
  int get measurementCount => _measurements;
  int get length => _entries.length;

  PhotoBoothTextLayout obtain(PhotoBoothText text, Size canvas) {
    final key = (
      text.text,
      text.color,
      text.backgroundColor,
      text.fontSize,
      text.rotation,
      canvas,
    );
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    final layout = text.layout(canvas);
    _measurements++;
    if (_entries.length >= capacity) {
      _entries.remove(_entries.keys.first)!.dispose();
    }
    _entries[key] = layout;
    return layout;
  }

  void dispose() {
    for (final layout in _entries.values) {
      layout.dispose();
    }
    _entries.clear();
  }
}

class PhotoBoothTextLayout {
  PhotoBoothTextLayout(
    this.fill,
    this.border,
    this.padding, {
    this.backgroundColor = 0,
    this.radius = 0,
  });
  final TextPainter fill, border;
  final double padding, radius;
  final int backgroundColor;
  Size get size => Size(fill.width + padding * 2, fill.height + padding * 2);
  void paint(Canvas canvas) {
    if (backgroundColor != 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: size.width,
            height: size.height,
          ),
          Radius.circular(radius),
        ),
        Paint()..color = Color(backgroundColor),
      );
    }
    final origin = Offset(-fill.width / 2, -fill.height / 2);
    border.paint(canvas, origin);
    fill.paint(canvas, origin);
  }

  void dispose() {
    fill.dispose();
    border.dispose();
  }
}
