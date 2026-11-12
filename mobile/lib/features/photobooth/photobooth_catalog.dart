import 'dart:convert';

import 'package:flutter/services.dart';

class PhotoBoothSlot {
  const PhotoBoothSlot(this.rect, this.photo);
  final Rect rect;
  final int photo;
}

class PhotoBoothFrame {
  const PhotoBoothFrame({
    required this.key,
    required this.theme,
    required this.size,
    required this.slots,
    this.asset,
    this.title,
    this.categoryTitle,
    this.format,
  });
  final String key;
  final String theme;
  final String? asset;
  final Size size;
  final List<PhotoBoothSlot> slots;
  final String? title;
  final String? categoryTitle;
  final String? format;
  int get photoCount => slots.map((slot) => slot.photo).toSet().length;
  String get categoryLabel =>
      categoryTitle ?? PhotoBoothCatalog.themes[theme] ?? theme;
  String get label => title ?? categoryLabel;
  String get formatLabel =>
      format ??
      (size == const Size(600, 1800)
          ? '2×6'
          : size == const Size(1200, 1800)
          ? '4×6'
          : '${size.width.toInt()} × ${size.height.toInt()}');

  static PhotoBoothFrame home(int count, {List<int>? photoIndices}) {
    final rows = count == 4 ? 2 : 1;
    final height = (960.0 - 48 - (rows - 1) * 16) / rows;
    return PhotoBoothFrame(
      key: 'home-$count',
      theme: 'home',
      title: 'Đơn giản',
      categoryTitle: 'Cơ bản',
      format: '3:2',
      size: const Size(1440, 960),
      slots: List.generate(
        count,
        (index) => PhotoBoothSlot(
          Rect.fromLTWH(
            24 + (index % 2) * 704.0,
            24 + (index ~/ 2) * (height + 16),
            688,
            height,
          ),
          photoIndices?[index] ?? index,
        ),
      ),
    );
  }
}

class PhotoBoothStickerAsset {
  const PhotoBoothStickerAsset({
    required this.key,
    required this.group,
    required this.asset,
    required this.size,
  });
  final String key;
  final String group;
  final String asset;
  final Size size;
}

class PhotoBoothCatalog {
  const PhotoBoothCatalog(this.frames, this.stickers);
  final List<PhotoBoothFrame> frames;
  final List<PhotoBoothStickerAsset> stickers;
  static const themes = {
    'classic': 'Classic',
    'film': 'Film',
    'birthday': 'Birthday',
    'christmas': 'Christmas',
    'halloween': 'Halloween',
  };
  static const groups = {
    'animals': 'Thú nhỏ',
    'cartoon': 'Hoạt hình',
    'rainbow': 'Cầu vồng',
    'birthday': 'Sinh nhật',
    'christmas': 'Giáng sinh',
    'halloween': 'Halloween',
  };

  static Future<PhotoBoothCatalog> load({AssetBundle? bundle}) async {
    final json = jsonDecode(
      await (bundle ?? rootBundle).loadString('assets/photobooth/catalog.json'),
    ) as Map<String, dynamic>;
    return PhotoBoothCatalog.fromJson(json);
  }

  factory PhotoBoothCatalog.fromJson(Map<String, dynamic> json) =>
      PhotoBoothCatalog(
        (json['frames'] as List).map((entry) {
          final f = entry as Map<String, dynamic>;
          return PhotoBoothFrame(
            key: f['key'],
            theme: f['theme'],
            asset: f['asset'],
            title: f['title'],
            categoryTitle: f['categoryTitle'],
            format: f['format'],
            size: Size(
              (f['width'] as num).toDouble(),
              (f['height'] as num).toDouble(),
            ),
            slots: (f['slots'] as List)
                .map(
                  (slot) => PhotoBoothSlot(
                    Rect.fromLTWH(
                      (slot['x'] as num).toDouble(),
                      (slot['y'] as num).toDouble(),
                      (slot['width'] as num).toDouble(),
                      (slot['height'] as num).toDouble(),
                    ),
                    slot['photo'] as int,
                  ),
                )
                .toList(),
          );
        }).toList(),
        (json['stickers'] as List)
            .where((entry) => entry['enabled'] == true)
            .map(
              (s) => PhotoBoothStickerAsset(
                key: s['key'],
                group: s['group'],
                asset: s['asset'],
                size: Size(
                  (s['width'] as num).toDouble(),
                  (s['height'] as num).toDouble(),
                ),
              ),
            )
            .toList(),
      );

  PhotoBoothFrame frame(String key, int count) {
    if (key == 'home-$count') return PhotoBoothFrame.home(count);
    return frames.firstWhere(
      (frame) => frame.key == key && frame.photoCount == count,
      orElse: () => frames.firstWhere(
        (frame) => frame.photoCount == count,
        orElse: () => PhotoBoothFrame.home(count),
      ),
    );
  }

  PhotoBoothStickerAsset sticker(String key) =>
      stickers.firstWhere((sticker) => sticker.key == key);
}
