import 'package:flutter/material.dart';

/// Border-radius tokens matching the prototype's "large radius throughout"
/// convention (see prototype_reference.md).
abstract final class AppRadius {
  static const small = 11.0; // inputs / small chips / rows
  static const medium = 14.0; // buttons / cards
  static const large = 20.0; // phone-frame-level containers / hero images
  static const pill = 999.0; // pill chips / FAB

  static BorderRadius get smallRadius => BorderRadius.circular(small);
  static BorderRadius get mediumRadius => BorderRadius.circular(medium);
  static BorderRadius get largeRadius => BorderRadius.circular(large);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}
