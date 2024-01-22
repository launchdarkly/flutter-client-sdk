import 'package:launchdarkly_common_client/ld_common_client.dart';
import 'package:launchdarkly_common_client/src/persistence/validating_persistence.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mock_persistence.dart';

class MockAdapter extends Mock implements LDLogAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });

  group('given good namespaces and keys', () {
    final namespace = 'LaunchDarkly_namespace0_1-2';
    final key = 'key_3_4-5';
    test('it sets data', () async {
      final mockPersistence = MockPersistence();
      final adapter = MockAdapter();
      final logger = LDLogger(adapter: adapter);
      final validating =
          ValidatingPersistence(persistence: mockPersistence, logger: logger);

      await validating.set(namespace, key, 'the-data');
      expect(mockPersistence.storage[namespace]?[key], 'the-data');

      verifyNever(() => adapter.log(any()));
    });

    test('it removes data', () async {
      final mockPersistence = MockPersistence();
      final adapter = MockAdapter();
      final logger = LDLogger(adapter: adapter);
      final validating =
          ValidatingPersistence(persistence: mockPersistence, logger: logger);

      await validating.set(namespace, key, 'the-data');
      await validating.remove(namespace, key);
      expect(mockPersistence.storage[namespace], isEmpty);

      verifyNever(() => adapter.log(any()));
    });

    test('it reads data', () async {
      final mockPersistence = MockPersistence();
      final adapter = MockAdapter();
      final logger = LDLogger(adapter: adapter);
      final validating =
          ValidatingPersistence(persistence: mockPersistence, logger: logger);

      await validating.set(namespace, key, 'the-data');
      final read = await validating.read(namespace, key);
      expect(read, 'the-data');

      verifyNever(() => adapter.log(any()));
    });
  });

  group('given a bad namespace', () {
    final namespace = 'HurlLoudly_namespace0_1-2';
    final key = 'key_3_4-5';

    test('it does not set data', () async {
      final mockPersistence = MockPersistence();
      final adapter = MockAdapter();
      final logger = LDLogger(adapter: adapter);
      final validating =
          ValidatingPersistence(persistence: mockPersistence, logger: logger);

      await validating.set(namespace, key, 'the-data');
      expect(mockPersistence.storage, isEmpty);

      final errorMessage =
          (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(errorMessage.level, LDLogLevel.error);
      expect(errorMessage.message,
          'Persistence namespace (HurlLoudly_namespace0_1-2) or key (key_3_4-5) is not valid.');
      expect(errorMessage.logTag, 'LaunchDarkly');
    });

    test('it does not read data', () async {
      final mockPersistence = MockPersistence();
      final adapter = MockAdapter();
      final logger = LDLogger(adapter: adapter);
      final validating =
          ValidatingPersistence(persistence: mockPersistence, logger: logger);

      mockPersistence.storage[namespace] = {key: 'data'};

      var read = await validating.read(namespace, key);
      expect(read, isNull);

      final errorMessage =
          (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(errorMessage.level, LDLogLevel.error);
      expect(errorMessage.message,
          'Persistence namespace (HurlLoudly_namespace0_1-2) or key (key_3_4-5) is not valid.');
      expect(errorMessage.logTag, 'LaunchDarkly');
    });

    test('it does not remove data', () async {
      final mockPersistence = MockPersistence();
      final adapter = MockAdapter();
      final logger = LDLogger(adapter: adapter);
      final validating =
          ValidatingPersistence(persistence: mockPersistence, logger: logger);

      mockPersistence.storage[namespace] = {key: 'data'};

      await validating.remove(namespace, key);
      expect(mockPersistence.storage[namespace]?[key], 'data');

      final errorMessage =
          (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(errorMessage.level, LDLogLevel.error);
      expect(errorMessage.message,
          'Persistence namespace (HurlLoudly_namespace0_1-2) or key (key_3_4-5) is not valid.');
      expect(errorMessage.logTag, 'LaunchDarkly');
    });
  });

  test('unicode word characters are also invalid', () async {
    final namespace = 'LaunchDarkly_test';
    final key = 'ö';
    final mockPersistence = MockPersistence();
    final adapter = MockAdapter();
    final logger = LDLogger(adapter: adapter);
    final validating =
        ValidatingPersistence(persistence: mockPersistence, logger: logger);

    await validating.set(namespace, key, 'the-data');
    expect(mockPersistence.storage, isEmpty);

    final errorMessage =
        (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
    expect(errorMessage.level, LDLogLevel.error);
    expect(errorMessage.message,
        'Persistence namespace (LaunchDarkly_test) or key (ö) is not valid.');
    expect(errorMessage.logTag, 'LaunchDarkly');
  });
}
