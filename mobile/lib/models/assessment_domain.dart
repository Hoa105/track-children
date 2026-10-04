import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// The 4 developmental domains used across Home, Assessment and Journal.
enum AssessmentDomain { grossMotor, fineMotor, language, socialEmotional }

extension AssessmentDomainX on AssessmentDomain {
  String get label => switch (this) {
        AssessmentDomain.grossMotor => 'Vận động thô',
        AssessmentDomain.fineMotor => 'Vận động tinh',
        AssessmentDomain.language => 'Ngôn ngữ',
        AssessmentDomain.socialEmotional => 'Xã hội – Cảm xúc',
      };

  Color get color => switch (this) {
        AssessmentDomain.grossMotor => AppColors.primary,
        AssessmentDomain.fineMotor => AppColors.purple,
        AssessmentDomain.language => AppColors.amber,
        AssessmentDomain.socialEmotional => AppColors.danger,
      };

  IconData get icon => switch (this) {
        AssessmentDomain.grossMotor => Icons.directions_run_rounded,
        AssessmentDomain.fineMotor => Icons.back_hand_rounded,
        AssessmentDomain.language => Icons.chat_bubble_rounded,
        AssessmentDomain.socialEmotional => Icons.emoji_emotions_rounded,
      };
}
