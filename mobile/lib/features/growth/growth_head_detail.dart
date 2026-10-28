import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_stature_detail.dart';

class GrowthHeadDetailScreen extends StatelessWidget {
  const GrowthHeadDetailScreen({
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
    metric: GrowthMetric.headCircumference,
  );
}
