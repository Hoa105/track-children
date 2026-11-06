import 'package:flutter/foundation.dart';

import '../../services/demo_store.dart';

/// Cache only confirmed server/demo overview; a failed request cannot invent a due assessment.
class AssessmentReminders extends ChangeNotifier {
  AssessmentReminders._();
  static final instance = AssessmentReminders._();
  final Map<String, Map<String, dynamic>> _states = {};
  String key(String child) => '${DemoStore.instance.parent['id']}/$child';
  Map<String, dynamic>? state(String child) => _states[key(child)];
  void put(String child, Map<String, dynamic> value) {
    _states[key(child)] = value;
    notifyListeners();
  }
}
