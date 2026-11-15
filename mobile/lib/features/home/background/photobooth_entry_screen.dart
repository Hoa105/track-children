import 'package:flutter/material.dart';

import '../../photobooth/photobooth_screen.dart';

import 'background_config.dart';

/// A finished Photobooth image. Home fits the entire artwork to its canvas
/// before cropping, preserving portrait/square frames and decorations.
class PhotoboothHomeInput {
  const PhotoboothHomeInput({required this.childId, required this.localPath});
  final String childId;
  final String localPath;
  BackgroundSource get source => BackgroundSource.photobooth;
}

typedef PhotoboothHomeLauncher = Future<PhotoboothHomeInput?> Function(
  BuildContext context,
  String childId,
);

class PhotoboothEntryScreen extends StatelessWidget {
  const PhotoboothEntryScreen({
    required this.accountId,
    required this.childId,
    this.onUseHome,
    super.key,
  });
  final String accountId;
  final String childId;
  final Future<BackgroundConfig?> Function(String path)? onUseHome;

  @override
  Widget build(BuildContext context) => PhotoBoothScreen(
    accountId: accountId,
    childId: childId,
    onUseHome: onUseHome,
  );
}
