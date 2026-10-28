import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_stature_detail.dart';

class GrowthBmiDetailScreen extends StatelessWidget {
  const GrowthBmiDetailScreen({
    required this.repository,
    this.easyReadMode = false,
    super.key,
  });

  final GrowthRepository repository;
  final bool easyReadMode;

  @override
  Widget build(BuildContext context) => GrowthStatureDetailScreen(
    repository: repository,
    easyReadMode: easyReadMode,
    bmiMode: true,
  );
}
