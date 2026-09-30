import 'package:flutter/foundation.dart';

import '../models/child.dart';
import '../models/child_share.dart';
import 'child_service.dart';

/// The child whose per-child data the app is currently showing — either one
/// of the account's own children, or a child someone shared with the
/// current user (then [sharedAccess] carries the granted permissions).
/// Account-level screens (hồ sơ mẹ, góc đồng hành, cài đặt) ignore this.
class ActiveChild {
  const ActiveChild(this.child, {this.sharedAccess});

  final Child child;
  final SharedChildAccess? sharedAccess;

  bool get isOwner => sharedAccess == null;

  bool canView(ShareSection section) => isOwner || sharedAccess!.permissions.canView(section);

  bool canEdit(ShareSection section) => isOwner || sharedAccess!.permissions.canEdit(section);

  /// "bé Bảo Minh" — the child's given name, for inline copy.
  String get shortName => 'bé ${child.name.split(' ').skip(1).join(' ')}';
}

/// App-wide selected child. Home, the child picker and the shared-profile
/// screen set it; per-child screens listen to it.
class ActiveChildController extends ValueNotifier<ActiveChild?> {
  ActiveChildController(this._children) : super(null);

  final ChildService _children;

  /// Falls back to the first own child the first time it's read.
  Future<ActiveChild?> ensure() async {
    if (value != null) return value;
    final children = await _children.getChildren();
    if (value == null && children.isNotEmpty) value = ActiveChild(children.first);
    return value;
  }

  void selectOwn(Child child) => value = ActiveChild(child);

  void selectShared(SharedChildAccess access) => value = ActiveChild(access.child, sharedAccess: access);

  /// Called when access to [childId] is lost (rời hồ sơ / bị thu hồi).
  Future<void> forget(String childId) async {
    if (value?.child.id != childId) return;
    value = null;
    await ensure();
  }
}
