import 'package:flutter/material.dart';

import '../../photobooth/photobooth_screen.dart';

import 'background_config.dart';

/// Prompt 03/04 supply a separately composed landscape Home image here.
/// Raw vertical photostrips must not be sent directly to the Home crop flow.
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
