class DefaultBackgroundAsset {
  const DefaultBackgroundAsset({
    required this.key,
    required this.fileName,
    this.role,
  });

  final String key;
  final String fileName;
  final String? role;

  String get assetPath => 'assets/images/scenery/backgrounds/default/$fileName';
}

/// One default per caregiver role; the neutral image covers other guardians.
const defaultBackgroundManifest = <DefaultBackgroundAsset>[
  DefaultBackgroundAsset(
    key: 'father',
    role: 'father',
    fileName: 'father-with-baby.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'mother',
    role: 'mother',
    fileName: 'mother-with-baby.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'grandfather',
    role: 'grandfather',
    fileName: 'grandfather-with-baby.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'grandmother',
    role: 'grandmother',
    fileName: 'grandma-with-baby.jpg',
  ),
  DefaultBackgroundAsset(key: 'neutral', fileName: 'boy-girl-are-playing.jpg'),
];

/// Pure resolver. No filesystem, profile mutation, or persistence side effects.
class DefaultBackgroundResolver {
  const DefaultBackgroundResolver({this.manifest = defaultBackgroundManifest});
  final List<DefaultBackgroundAsset> manifest;

  DefaultBackgroundAsset? resolve({String? role}) {
    final normalizedRole = role == 'other_guardian' ? 'guardian' : role;
    return manifest
            .where(
              (asset) => asset.role != null && asset.role == normalizedRole,
            )
            .firstOrNull ??
        manifest.where((asset) => asset.role == null).firstOrNull ??
        manifest.firstOrNull;
  }
}
