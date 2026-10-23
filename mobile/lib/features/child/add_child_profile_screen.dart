import '../../services/demo_store.dart';

import 'package:flutter/material.dart';

import 'child_profile_screen.dart';

class AddChildProfileScreen extends StatelessWidget {
  const AddChildProfileScreen({required this.onOpenHomePreview, super.key});
  final ValueChanged<String> onOpenHomePreview;
  @override
  Widget build(BuildContext context) => ChildProfileScreen(
    onOpenHomePreview: onOpenHomePreview,
    onSave: DemoStore.instance.signedIn
        ? (fields, avatar) async {
            await DemoStore.instance.saveChild(null, fields);
            onOpenHomePreview(fields['full_name'] as String);
          }
        : null,
  );
}
