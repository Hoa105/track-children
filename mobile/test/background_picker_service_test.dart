import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/home/background/background_draft.dart';
import 'package:track_children/features/home/background/background_files.dart';
import 'package:track_children/features/home/background/background_picker_service.dart';

class _Picker extends ImagePicker {
  XFile? result;
  PlatformException? error;
  bool? fullMetadata;
  int recoveries = 0;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.gallery);
    fullMetadata = requestFullMetadata;
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    recoveries++;
    return LostDataResponse(files: result == null ? null : [result!]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Picker native;
  late BackgroundPickerService service;
  late BackgroundFiles files;
  late String source;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await Directory('build/background_picker_tests').create(recursive: true);
    final dir = await Directory('build/background_picker_tests')
        .createTemp('run_');
    source = '${dir.path}/original.jpg';
    await File(source).writeAsString('original source');
    files = BackgroundFiles(rootPath: '${dir.path}/managed');
    native = _Picker();
    service = BackgroundPickerService(picker: native, files: files);
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'picker requests no full metadata and cancel leaves no pending marker',
    () async {
      expect(await service.pick(accountId: 'a', childId: 'one'), isNull);
      expect(native.fullMetadata, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString(
          BackgroundPickerService.pendingKey,
        ),
        isNull,
      );
      native.result = XFile(source);
      final picked = await service.pick(accountId: 'a', childId: 'one');
      expect(await files.isPending(picked!), isTrue);
      await files.removePending(picked);
      expect(await File(source).exists(), isTrue);
    },
  );

  test(
    'permission denial is recoverable and does not retain a picker marker',
    () async {
      native.error = PlatformException(code: 'photo_access_denied');
      await expectLater(
        service.pick(accountId: 'a', childId: 'one'),
        throwsA(
          isA<BackgroundImageException>().having(
            (error) => error.canOpenSettings,
            'canOpenSettings',
            isTrue,
          ),
        ),
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          BackgroundPickerService.pendingKey,
        ),
        isNull,
      );
      native.error = null;
      native.result = XFile(source);
      expect(await service.pick(accountId: 'a', childId: 'one'), isNotNull);
    },
  );

  test('lost data is retrieved only for our marker and resumed only by its owner/child', () async {
    native.result = XFile(source);
    await service.recoverInterrupted();
    expect(native.recoveries, 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      BackgroundPickerService.pendingKey,
      jsonEncode({'accountId': 'a', 'childId': 'one'}),
    );
    await service.recoverInterrupted();
    expect(native.recoveries, 1);
    expect(await service.takeRecovered(accountId: 'b', childId: 'one'), isNull);
    expect(await service.takeRecovered(accountId: 'a', childId: 'two'), isNull);
    final recovered = await service.takeRecovered(
      accountId: 'a',
      childId: 'one',
    );
    expect(await File(recovered!).exists(), isTrue);
    expect(await service.takeRecovered(accountId: 'a', childId: 'one'), isNull);
    expect(prefs.getString(BackgroundPickerService.pendingKey), isNull);
    expect(await File(source).exists(), isTrue);
  });

  test('settings recovery handles native success, false and failure', () async {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'openAppSettings');
      return true;
    });
    await service.openSettings();
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    await expectLater(
      service.openSettings(),
      throwsA(
        isA<BackgroundImageException>().having(
          (e) => e.canOpenSettings,
          'recovery',
          isTrue,
        ),
      ),
    );
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    await expectLater(
      service.openSettings(),
      throwsA(isA<BackgroundImageException>()),
    );
  });
}
