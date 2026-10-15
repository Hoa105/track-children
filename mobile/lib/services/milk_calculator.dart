/// Reference volume, not a prescription or a powder-to-water ratio.
class MilkEstimate {
  const MilkEstimate(this.dailyMl, this.feeds);
  final double dailyMl;
  final int feeds;
  double get perFeedMl => dailyMl / feeds;
}

String? milkEligibility({
  required DateTime? birthDate,
  required DateTime today,
  required double weightKg,
  required bool healthyFullTerm,
  required bool exclusivelyBottleFed,
}) {
  if (!weightKg.isFinite || weightKg <= 0) return 'Nhập cân nặng hợp lệ.';
  if (birthDate == null || birthDate.isAfter(today)) {
    return 'Cần ngày sinh hợp lệ trong hồ sơ bé.';
  }
  final birth = DateTime.utc(birthDate.year, birthDate.month, birthDate.day);
  final day = DateTime.utc(today.year, today.month, today.day);
  if (day.difference(birth).inDays < 7) {
    return 'Bé trong tuần đầu sau sinh cần hướng dẫn lượng sữa riêng từ nhân viên y tế.';
  }
  // Conservative product scope. Not an age cutoff attributed to WHO.
  final sixMonths = DateTime.utc(
    birth.year,
    birth.month + 6,
    birth.day.clamp(1, DateTime.utc(birth.year, birth.month + 7, 0).day),
  );
  if (!day.isBefore(sixMonths)) {
    return 'Công cụ hiện hỗ trợ bé từ đủ 7 ngày đến dưới 6 tháng. Bé lớn hơn cần đánh giá cùng chế độ ăn bổ sung.';
  }
  if (weightKg < 2.5 || !healthyFullTerm) {
    return 'Bé dưới 2,5 kg, sinh non hoặc có vấn đề sức khỏe cần kế hoạch nuôi dưỡng riêng.';
  }
  if (!exclusivelyBottleFed) {
    return 'Không dùng tổng lượng này để tính sữa bổ sung khi bé đang bú mẹ trực tiếp.';
  }
  return null;
}

MilkEstimate estimateMilk(double weightKg, int feeds) {
  if (!weightKg.isFinite || weightKg < 2.5 || feeds < 1 || feeds > 24) {
    throw ArgumentError('Cân nặng hoặc số cữ không hợp lệ');
  }
  return MilkEstimate(weightKg * 150, feeds);
}
