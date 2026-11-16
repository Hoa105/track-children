import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/photobooth/photobooth_catalog.dart';
import 'package:track_children/features/photobooth/photobooth_edit.dart';
import 'package:track_children/features/photobooth/photobooth_text.dart';

import 'photobooth_editor_model_test.dart' show editorSession;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Nunito')
          ..addFont(rootBundle.load('assets/fonts/nunito/Nunito-Variable.ttf')))
        .load();
  });

  test('long Vietnamese captions fit the canvas after movement, resize and rotation', () {
    for (final canvas in const [
      Size(600, 1800),
      Size(1200, 1800),
      Size(1800, 600),
      Size(1500, 1500),
      Size(1440, 960),
    ]) {
      for (final angle in [0.0, math.pi / 4, math.pi / 2, math.pi]) {
        final caption = PhotoBoothText(
          id: 0,
          text: 'Bé yêu lớn khôn mỗi ngày\nGia đình mình bên nhau\nKỷ niệm thật đáng yêu',
          fontSize: .16,
          backgroundColor: 0xFFEFDCC0,
        ).move(canvas, x: -3, y: 4, rotation: angle);
        final layout = caption.layout(canvas);
        try {
          expect(layout.fill.text!.toPlainText(), caption.text);
          final dx =
              (layout.size.width * math.cos(angle).abs() +
                  layout.size.height * math.sin(angle).abs()) /
              2;
          final dy =
              (layout.size.width * math.sin(angle).abs() +
                  layout.size.height * math.cos(angle).abs()) /
              2;
          expect(caption.x * canvas.width - dx, greaterThanOrEqualTo(-1e-6));
          expect(
            caption.x * canvas.width + dx,
            lessThanOrEqualTo(canvas.width + 1e-6),
          );
          expect(caption.y * canvas.height - dy, greaterThanOrEqualTo(-1e-6));
          expect(
            caption.y * canvas.height + dy,
            lessThanOrEqualTo(canvas.height + 1e-6),
          );
          expect(
            caption.hit(
              Offset(caption.x * canvas.width, caption.y * canvas.height),
              canvas,
            ),
            isTrue,
          );
          expect(caption.hit(const Offset(-5000, -5000), canvas), isFalse);
        } finally {
          layout.dispose();
        }
      }
    }
  });

  test('text edits participate in dirty state and share unchanged image/sticker state', () {
    final editor = PhotoBoothEditorController(editorSession());
    final frame = PhotoBoothFrame.home(4);
    expect(editor.addText('   ', frame), isNull);
    expect(editor.dirty, isFalse);
    final text = editor.addText('  Bé yêu 2026  ', frame)!;
    expect(text.text, 'Bé yêu 2026');
    expect(editor.dirty, isTrue);
    editor.markSaved();
    final captions = editor.draft.texts;
    editor.setPhoto(0, const PhotoBoothPhotoTransform(zoom: 2));
    expect(editor.draft.texts, same(captions));
    final photos = editor.draft.photos;
    final stickers = editor.draft.stickers;
    final before = editor.draft.fingerprint;
    editor.changeText(
      text
          .copy(
            text: 'Sinh nhật vui vẻ',
            color: 0xFFE96392,
            backgroundColor: 0xFF317EC1,
            fontSize: .12,
          )
          .move(frame.size, x: .2, rotation: .5),
    );
    expect(editor.draft.fingerprint, isNot(before));
    expect(editor.draft.photos, same(photos));
    expect(editor.draft.stickers, same(stickers));
    final caption = editor.draft.texts.single;
    expect(caption.backgroundColor, 0xFF317EC1);
    expect(caption.toJson()['backgroundColor'], 0xFF317EC1);
    final layout = caption.layout(frame.size);
    expect(
      (layout.border.text! as TextSpan).style!.foreground!.color.toARGB32(),
      caption.color,
    );
    layout.dispose();
    expect(caption.effectiveBorderColor, caption.color);
    final plain = caption.copy(backgroundColor: 0);
    final plainLayout = plain.layout(frame.size);
    final withBackground = caption.layout(frame.size);
    expect(withBackground.size.width, greaterThan(plainLayout.size.width));
    expect(withBackground.size.height, greaterThan(plainLayout.size.height));
    plainLayout.dispose();
    withBackground.dispose();
    expect(plain.backgroundColor, 0);
    expect(caption.copy(color: 0xFFE67D3C).effectiveBorderColor, 0xFFE67D3C);
    editor.markSaved();
    editor.changeText(caption.copy(backgroundColor: 0xFFE67D3C));
    expect(editor.dirty, isTrue);
    expect(editor.draft.fingerprint, isNot(before));
    var notifications = 0;
    editor.addListener(() => notifications++);
    editor.changeText(editor.draft.texts.single);
    expect(notifications, 0);
    for (var i = 1; i < 8; i++) {
      expect(editor.addText('Chữ $i', frame), isNotNull);
    }
    expect(editor.addText('Thừa', frame), isNull);
    editor.removeText(text.id);
    expect(editor.draft.texts, hasLength(7));
    editor.dispose();
  });

  test('layout cache reuses paragraphs while dragging and invalidates styling and canvas changes', () {
    final layouts = PhotoBoothTextLayoutCache();
    const size = Size(1440, 960);
    const text = PhotoBoothText(
      id: 1,
      text: 'Bé yêu\nGia đình mình',
      backgroundColor: 0xFF23332E,
    );
    final original = layouts.obtain(text, size);
    for (var i = 0; i < 100; i++) {
      final moved = text.move(size, x: .3 + i * .003, layouts: layouts);
      expect(layouts.obtain(moved, size), same(original));
      expect(
        moved.hit(
          Offset(moved.x * size.width, moved.y * size.height),
          size,
          layouts: layouts,
        ),
        isTrue,
      );
    }
    expect(layouts.measurementCount, 1);
    expect(
      layouts.obtain(text.copy(color: 0xFFE96392), size),
      isNot(same(original)),
    );
    expect(
      layouts.obtain(text.copy(backgroundColor: 0), size),
      isNot(same(original)),
    );
    expect(
      layouts.obtain(text.copy(fontSize: .1), size),
      isNot(same(original)),
    );
    expect(
      layouts.obtain(text.copy(text: 'Nội dung khác'), size),
      isNot(same(original)),
    );
    expect(
      layouts.obtain(text.move(size, rotation: .4, layouts: layouts), size),
      isNot(same(original)),
    );
    expect(layouts.obtain(text, const Size(600, 1800)), isNot(same(original)));
    expect(layouts.measurementCount, 7);
    layouts.dispose();
    expect(layouts.length, 0);
  });

  test('layout cache bounds paragraph memory and evicts the least recently used layout', () {
    final layouts = PhotoBoothTextLayoutCache(capacity: 2);
    const size = Size(1440, 960);
    const first = PhotoBoothText(id: 1, text: 'Một');
    const second = PhotoBoothText(id: 2, text: 'Hai');
    const third = PhotoBoothText(id: 3, text: 'Ba');
    final retained = layouts.obtain(first, size);
    layouts.obtain(second, size);
    layouts.obtain(first, size);
    layouts.obtain(third, size);
    expect(layouts.length, 2);
    expect(layouts.obtain(first, size), same(retained));
    layouts.obtain(second, size);
    expect(layouts.measurementCount, 4);
    expect(layouts.length, 2);
    layouts.dispose();
    layouts.dispose();
  });

  test(
    'Home preserves entered text independently from the memento draft',
    () async {
      final catalog = await PhotoBoothCatalog.load();
      final editor = PhotoBoothEditorController(editorSession());
      final frame = editor.resolveFrame(catalog);
      editor.addText(
        'Gia đình nhỏ\nHạnh phúc to',
        frame,
        color: 0xFF317EC1,
        backgroundColor: 0xFFE67D3C,
      );
      final original = editor.draft.fingerprint;
      editor.prepareHome(catalog);
      expect(editor.draft.texts.single.text, 'Gia đình nhỏ\nHạnh phúc to');
      expect(editor.draft.texts.single.color, 0xFF317EC1);
      expect(editor.draft.texts.single.backgroundColor, 0xFFE67D3C);
      editor.changeText(
        editor.draft.texts.single
            .copy(text: 'Bản Home')
            .move(editor.resolveFrame(catalog).size),
      );
      editor.restoreStrip();
      expect(editor.draft.fingerprint, original);
      editor.setFrame(catalog.frame('film-1200', 4), catalog);
      expect(editor.draft.texts.single.text, 'Gia đình nhỏ\nHạnh phúc to');
      expect(editor.draft.texts.single.backgroundColor, 0xFFE67D3C);
      editor.dispose();
    },
  );

  test('raising a caption changes stacking order without changing its style or other layers', () {
    final editor = PhotoBoothEditorController(editorSession());
    final frame = PhotoBoothFrame.home(4);
    final first = editor.addText(
      'Dưới',
      frame,
      color: 0xFFE96392,
      backgroundColor: 0xFF23332E,
    )!;
    final second = editor.addText('Trên', frame)!;
    final photos = editor.draft.photos;
    final stickers = editor.draft.stickers;
    editor.markSaved();
    editor.raiseText(first.id);
    expect(editor.draft.texts.map((text) => text.id), [second.id, first.id]);
    expect(editor.draft.texts.last, same(first));
    expect(editor.draft.photos, same(photos));
    expect(editor.draft.stickers, same(stickers));
    expect(editor.dirty, isTrue);
    var notifications = 0;
    editor.addListener(() => notifications++);
    editor.raiseText(first.id);
    editor.raiseText(-1);
    expect(notifications, 0);
    editor.dispose();
  });
}
