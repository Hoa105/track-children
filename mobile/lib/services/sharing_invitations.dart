import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'sharing_api.dart';

/// Lời mời chia sẻ hồ sơ bé đang chờ tài khoản này trả lời. Dùng chung cho
/// màn Thông báo, chuông ở trang chủ và màn "Hồ sơ được chia sẻ với tôi".
class SharingInvitations extends ChangeNotifier {
  SharingInvitations._();
  static SharingInvitations instance = SharingInvitations._();

  /// Nguồn lời mời; null dùng [SharingApi] thật (test thay bằng bản giả).
  @visibleForTesting
  static Future<List<IncomingInvitation>> Function()? fetchOverride;

  @visibleForTesting
  static void resetForTesting() {
    instance = SharingInvitations._();
    fetchOverride = null;
  }

  List<IncomingInvitation> _invitations = const [];
  Future<void>? _loading;

  List<IncomingInvitation> get invitations => _invitations;

  /// Tải lại từ máy chủ. Chưa đăng nhập tài khoản thật / lỗi mạng: giữ danh sách cũ.
  Future<void> refresh() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    final fetch = fetchOverride;
    if (fetch == null &&
        (AuthService.instance.user == null || AuthService.instance.demoMode)) {
      _set(const []);
      return;
    }
    try {
      _set(await (fetch ?? SharingApi().incoming)());
    } catch (_) {
      // Thông báo khác vẫn hiển thị khi không tải được lời mời.
    }
  }

  /// Gán danh sách vừa tải ở nơi khác (vd. màn lời mời) để thông báo cập nhật ngay.
  void replace(List<IncomingInvitation> invitations) => _set(invitations);

  /// Đăng xuất: không giữ lời mời của tài khoản trước.
  void clear() => _set(const []);

  void _set(List<IncomingInvitation> value) {
    _invitations = List.unmodifiable(value);
    notifyListeners();
  }
}
