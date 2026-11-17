import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/photobooth/photobooth_export.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(PhotoBoothGallery.channel, null),
  );

  test('only explicit save sends one image to native gallery', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(PhotoBoothGallery.channel, (call) async {
      calls.add(call);
      return true;
    });
    await const PhotoBoothGallery().save('/owned/finished.png');
    expect(calls.single.method, 'saveImage');
    expect(calls.single.arguments, {'path': '/owned/finished.png'});
  });
  test(
    'permission denied offers Settings without disclosing native details',
    () async {
      messenger.setMockMethodCallHandler(PhotoBoothGallery.channel, (_) async {
        throw PlatformException(
          code: 'permission_denied',
          message: '/private/photo.png',
        );
      });
      await expectLater(
        const PhotoBoothGallery().save('/owned/finished.png'),
        throwsA(
          isA<PhotoBoothException>()
              .having((e) => e.canOpenSettings, 'settings', true)
              .having(
                (e) => e.message,
                'sanitized',
                isNot(contains('/private')),
              ),
        ),
      );
    },
  );
  for (final failure in ['false', 'native', 'missing']) {
    test('$failure never reports success', () async {
      messenger.setMockMethodCallHandler(PhotoBoothGallery.channel, (_) async {
        if (failure == 'native') throw PlatformException(code: 'disk_full');
        if (failure == 'missing') throw MissingPluginException();
        return false;
      });
      await expectLater(
        const PhotoBoothGallery().save('/owned/finished.png'),
        throwsA(isA<PhotoBoothException>()),
      );
    });
  }
}
