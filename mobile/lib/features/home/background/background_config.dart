enum BackgroundSource {
  defaultImage('default'),
  gallery('gallery'),
  photobooth('photobooth');

  const BackgroundSource(this.value);
  final String value;
}

/// Only metadata is persisted. Image files remain on this device.
class BackgroundConfig {
  const BackgroundConfig({
    required this.childId,
    this.source = BackgroundSource.defaultImage,
    this.selectedDefaultKey,
    this.finalLocalPath,
    this.updatedAt,
  });

  final String childId;
  final BackgroundSource source;
  final String? selectedDefaultKey;
  final String? finalLocalPath;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => {
    'childId': childId,
    'source': source.value,
    'selectedDefaultKey': selectedDefaultKey,
    'finalLocalPath': finalLocalPath,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  factory BackgroundConfig.fromJson(Map<String, dynamic> json) {
    final childId = json['childId'];
    final source = BackgroundSource.values
        .where((value) => value.value == json['source'])
        .firstOrNull;
    if (childId is! String || childId.isEmpty || source == null) {
      throw const FormatException('Invalid background configuration');
    }
    return BackgroundConfig(
      childId: childId,
      source: source,
      selectedDefaultKey: json['selectedDefaultKey'] as String?,
      finalLocalPath: json['finalLocalPath'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }
}
