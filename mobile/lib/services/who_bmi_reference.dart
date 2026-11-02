import 'dart:math' as math;

/// Utility for calculating age intervals in completed months.
class WhoBmiReference {
  static int ageMonths(DateTime birth, DateTime measured) {
    var months =
        (measured.year - birth.year) * 12 + measured.month - birth.month;
    final last = DateTime(measured.year, measured.month + 1, 0).day;
    if (measured.day < math.min(birth.day, last)) months--;
    return months;
  }
}
