import 'package:flutter/material.dart';
import 'activity.dart';

class ActivityGroup {
  final String id;
  final String name;
  final Color tint;
  final ActivityKind kind;
  final String emoji;
  final String description;
  final List<Activity> items;

  const ActivityGroup({
    required this.id,
    required this.name,
    required this.tint,
    required this.kind,
    required this.emoji,
    required this.description,
    required this.items,
  });

  int get doneCount => items.where((a) => a.isDone).length;
}
