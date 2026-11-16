import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/photobooth/photobooth_camera.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');

  tearDown(
    () =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
  );

  test(
    'Settings recovery opens app settings without requesting permissions',
    () async {
      final methods = <String>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        methods.add(call.method);
        return true;
      });
      await DevicePhotoBoothCamera().openSettings();
      expect(methods, ['openAppSettings']);
    },
  );

  test(
    'Settings recovery explains manual steps when OS returns false',
    () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => false,
      );
      await expectLater(
        DevicePhotoBoothCamera().openSettings(),
        throwsA(
          isA<PhotoBoothException>().having(
            (error) => error.message,
            'message',
            contains('mở Cài đặt của thiết bị'),
          ),
        ),
      );
    },
  );

  test(
    'Settings platform failure does not expose native error details',
    () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        throw PlatformException(
          code: 'settings_unavailable',
          message: 'native details',
        );
      });
      await expectLater(
        DevicePhotoBoothCamera().openSettings(),
        throwsA(
          isA<PhotoBoothException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('bật quyền Camera'),
              isNot(contains('native details')),
            ),
          ),
        ),
      );
    },
  );
}
