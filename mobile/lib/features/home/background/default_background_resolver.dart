class DefaultBackgroundAsset {
  const DefaultBackgroundAsset({
    required this.key,
    required this.fileName,
    this.role,
    this.childGender,
  });

  final String key;
  final String fileName;
  final String? role;
  final String? childGender;

  String get assetPath => 'assets/images/scenery/backgrounds/default/$fileName';
}

/// Explicit mapping of the nine source files supplied by the project.
/// Role-specific images must precede neutral fallbacks in the resolver.
const defaultBackgroundManifest = <DefaultBackgroundAsset>[
  DefaultBackgroundAsset(
    key: 'father-boy',
    role: 'father',
    childGender: 'male',
    fileName: 'father-son-drawing-together-home.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'father-girl',
    role: 'father',
    childGender: 'female',
    fileName: 'father-daughter-with-toys-home.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'mother-boy',
    role: 'mother',
    childGender: 'male',
    fileName: 'mother-playing-with-lovely-son-bedroom.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'mother-girl',
    role: 'mother',
    childGender: 'female',
    fileName: 'mother-daughter-studying-alphabet.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'grandfather-boy',
    role: 'grandfather',
    childGender: 'male',
    fileName: 'happy-boy-grandson-playing-game-tablet-with-old-senior-man-grandfather-home.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'grandfather-girl',
    role: 'grandfather',
    childGender: 'female',
    fileName: 'grandfather-teach-granddaughter-drawing-doing-homework-home.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'grandmother-boy',
    role: 'grandmother',
    childGender: 'male',
    fileName: 'grandson-grandmother-with-homework.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'grandmother-girl',
    role: 'grandmother',
    childGender: 'female',
    fileName: 'granddaughter-grandmother-with-homework.jpg',
  ),
  DefaultBackgroundAsset(
    key: 'neutral',
    fileName: 'boy-girl-are-happily-playing-colorful-wood-block-toy.jpg',
  ),
];

/// Pure resolver. No filesystem, profile mutation, or persistence side effects.
class DefaultBackgroundResolver {
  const DefaultBackgroundResolver({this.manifest = defaultBackgroundManifest});
  final List<DefaultBackgroundAsset> manifest;

  DefaultBackgroundAsset? resolve({String? role, String? childGender}) {
    final normalizedRole = role == 'other_guardian' ? 'guardian' : role;
    final neutral = manifest
        .where((a) => a.role == null && a.childGender == null)
        .firstOrNull;
    // Unknown roles/genders use the project's explicitly chosen neutral image.
    if (normalizedRole == 'guardian' ||
        !const {
          'father',
          'mother',
          'grandfather',
          'grandmother',
        }.contains(normalizedRole) ||
        !const {'male', 'female'}.contains(childGender)) {
      return neutral ?? manifest.firstOrNull;
    }
    return manifest
            .where(
              (a) => a.role == normalizedRole && a.childGender == childGender,
            )
            .firstOrNull ??
        manifest
            .where((a) => a.role == null && a.childGender == childGender)
            .firstOrNull ??
        neutral ??
        manifest.firstOrNull;
  }
}
