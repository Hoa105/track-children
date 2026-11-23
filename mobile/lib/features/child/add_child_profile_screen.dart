import 'package:flutter/material.dart';

import '../../services/demo_store.dart';
import 'child_profile_screen.dart';

class AddChildProfileScreen extends StatelessWidget {
  const AddChildProfileScreen({required this.onOpenHomePreview, super.key});

  final ValueChanged<String> onOpenHomePreview;

  @override
  Widget build(BuildContext context) => ChildProfileScreen(
    onOpenHomePreview: onOpenHomePreview,
    onSave: (fields, avatar) async {
      final childId = await DemoStore.instance.saveChild(null, fields);
      if (childId.isNotEmpty) {
        DemoStore.instance.selectChild(childId);
      }
      onOpenHomePreview(fields['full_name'] as String);
    },
  );
}
