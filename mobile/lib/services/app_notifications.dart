import 'demo_store.dart';
import 'vaccination_schedule.dart';

class CareNotification {
  const CareNotification({
    required this.id,
    required this.childId,
    required this.title,
    required this.message,
    required this.date,
  });
  final String id, childId, title, message;
  final DateTime date;
}

/// In-app reminders derived from the same local records as the vaccination book.
List<CareNotification> careNotifications(DemoStore store, {DateTime? now}) {
  if (!store.signedIn || store.parent['notifications'] == false) return [];
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final result = <CareNotification>[];
  for (final child in store.children) {
    final childId = child['id'] as String;
    final dob = DateTime.tryParse(child['date_of_birth'] as String? ?? '');
    if (dob == null) continue;
    // Same schedule as the vaccination book: TCMR + dịch vụ the child follows,
    // due dates counted from earlier doses, and the parent's own appointments.
    final upcoming = [
      for (final v in buildVaccinationSchedule(
        childId: childId,
        dob: dob,
        entries: store.vaccinations(childId),
        plans: store.vaccinePlans(childId),
        today: today,
      ))
        if (v.record == null)
          (
            id: v.dose.id,
            name: '${v.dose.name} · ${v.dose.doseLabel}',
            date: v.dueDate,
            booked: v.hasAppointment,
            place: v.appointmentPlace,
          ),
    ];
    for (final dose in upcoming) {
      final date = DateTime(dose.date.year, dose.date.month, dose.date.day);
      final days = date.difference(today).inDays;
      // Surface recent and near-term reminders, rather than all missing history.
      if (days < -30 || days > 7) continue;
      final phase = days < 0
          ? 'past'
          : days == 0
          ? 'today'
          : 'soon';
      // Có lịch hẹn bố mẹ đã đặt thì nhắc theo ngày hẹn
      final kind = dose.booked ? 'Lịch hẹn' : 'Lịch dự kiến';
      final status = days < 0
          ? '$kind đã qua'
          : days == 0
          ? '$kind hôm nay'
          : '$kind sắp tới';
      result.add(
        CareNotification(
          id: '$childId:${dose.id}:${date.toIso8601String()}:$phase',
          childId: childId,
          title: '${child['full_name']} · $status',
          message:
              '${dose.name}\n${dose.booked ? 'Hẹn' : 'Ngày'} ${date.day}/${date.month}/${date.year}${dose.place.isEmpty ? '' : ' · ${dose.place}'}. Xem sổ tiêm để kiểm tra và cập nhật.',
          date: date,
        ),
      );
    }
  }
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

Set<String> readNotificationIds(DemoStore store) =>
    Set<String>.from(store.parent['readNotifications'] as List? ?? []);
int unreadNotificationCount(DemoStore store) {
  final read = readNotificationIds(store);
  return careNotifications(store).where((n) => !read.contains(n.id)).length;
}
