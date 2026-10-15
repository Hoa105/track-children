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
    final records = store.vaccinations(childId);
    final done = records
        .where((r) => r['given'] == true)
        .map((r) => r['id'])
        .toSet();
    final upcoming = <({String id, String name, DateTime date})>[
      for (final dose in tcmrSchedule)
        if (!done.contains(dose.id))
          (
            id: dose.id,
            name: '${dose.name} · ${dose.doseLabel}',
            date: dose.dueDate(dob),
          ),
      for (final record in records)
        if (record['custom'] == true && record['given'] != true)
          (
            id: record['id'] as String,
            name: '${record['name']} · ${record['doseLabel']}',
            date: DateTime.parse(record['date'] as String),
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
      final status = days < 0
          ? 'Lịch dự kiến đã qua'
          : days == 0
          ? 'Lịch dự kiến hôm nay'
          : 'Lịch dự kiến sắp tới';
      result.add(
        CareNotification(
          id: '$childId:${dose.id}:${date.toIso8601String()}:$phase',
          childId: childId,
          title: '${child['full_name']} · $status',
          message:
              '${dose.name}\nNgày ${date.day}/${date.month}/${date.year}. Xem sổ tiêm để kiểm tra và cập nhật.',
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
