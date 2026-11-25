import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/src/flutter_state_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const eventChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity_status');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Completer<List<String>> pendingCheck;
  late int checkCalls;

  setUp(() {
    pendingCheck = Completer();
    checkCalls = 0;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'check') {
        checkCalls++;
        return pendingCheck.future;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(eventChannel, (call) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockMethodCallHandler(eventChannel, null);
  });

  test('drops a connectivity result that arrives after dispose', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final detector = FlutterStateDetector();
      // Let the constructor's checkConnectivity call reach the platform.
      await Future<void>.delayed(Duration.zero);
      expect(checkCalls, 1);

      detector.dispose();
      pendingCheck.complete(['wifi']);
      await Future<void>.delayed(Duration.zero);
    }, (error, _) => errors.add(error));

    expect(errors, isEmpty);
  });
}
