import 'package:flutter/material.dart';

class HomePreviewData {
  const HomePreviewData._();

  static const childAge = '8 tháng tuổi';
  static const lastGrowthDate = 'Cập nhật 08/10';

  static const measurements = [
    GrowthPreviewMeasurement(
      label: 'Cân nặng',
      value: '8,1',
      unit: 'kg',
      icon: Icons.monitor_weight_outlined,
    ),
    GrowthPreviewMeasurement(
      label: 'Chiều cao',
      value: '68',
      unit: 'cm',
      icon: Icons.height_rounded,
    ),
  ];

  static const milestones = [
    MilestonePreview(
      age: 'Sơ sinh · Mầm tre',
      title: 'Búp măng khép kín',
      description: 'Chặng khởi đầu của hành trình.',
      stage: 0,
    ),
    MilestonePreview(
      age: '4 tháng',
      title: 'Măng vươn mình',
      description: 'Từng ngày lớn lên theo cách riêng.',
      stage: 1,
    ),
    MilestonePreview(
      age: childAge,
      title: 'Tre đón lá',
      description: 'Mở rộng thế giới qua những khám phá mới.',
      stage: 2,
    ),
  ];

  static const journalEntries = [
    JournalPreviewEntry(
      time: '08:30 · Hôm nay',
      title: 'Cữ sữa buổi sáng',
      detail: '150 ml',
      category: 'Lượng sữa',
    ),
    JournalPreviewEntry(
      time: '16:10 · Hôm qua',
      title: 'Cùng bé nghe nhạc',
      detail: 'Hoạt động',
      category: 'Hoạt động',
    ),
  ];
}

class GrowthPreviewMeasurement {
  const GrowthPreviewMeasurement({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
}

class MilestonePreview {
  const MilestonePreview({
    required this.age,
    required this.title,
    required this.description,
    required this.stage,
  });

  final String age;
  final String title;
  final String description;
  final int stage;
}

class JournalPreviewEntry {
  const JournalPreviewEntry({
    required this.time,
    required this.title,
    required this.detail,
    required this.category,
  });

  final String time;
  final String title;
  final String detail;
  final String category;
}
