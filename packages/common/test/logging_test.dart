import 'package:test/test.dart';
import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:mocktail/mocktail.dart';

class MockAdapter extends Mock implements LDLogAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });

  test('logging can be disabled', () {
    final adapter = MockAdapter();
    final logger = LDLogger(adapter: adapter, level: LDLogLevel.none);

    logger.debug('debug');
    logger.info('info');
    logger.warn('warn');
    logger.error('error');

    verifyNever(() => adapter.log(any()));
  });

  test('debug level can be disabled', () {
    final adapter = MockAdapter();
    final logger = LDLogger(adapter: adapter, level: LDLogLevel.info);

    logger.debug('debug');
    logger.info('info');
    logger.warn('warn');
    logger.error('error');

    verify(() => adapter.log(any())).called(3);
  });

  test('info level can be disabled', () {
    final adapter = MockAdapter();
    final logger = LDLogger(adapter: adapter, level: LDLogLevel.warn);

    logger.debug('debug');
    logger.info('info');
    logger.warn('warn');
    logger.error('error');

    verify(() => adapter.log(any())).called(2);
  });

  test('warn level can be disabled', () {
    final adapter = MockAdapter();
    final logger = LDLogger(adapter: adapter, level: LDLogLevel.error);

    logger.debug('debug');
    logger.info('info');
    logger.warn('warn');
    logger.error('error');

    verify(() => adapter.log(any())).called(1);
  });

  test('can log at each level', () {
    final adapter = MockAdapter();
    final logger = LDLogger(adapter: adapter, level: LDLogLevel.debug);

    logger.debug('debug message');
    final debugMessage =
        (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
    expect(debugMessage.level, LDLogLevel.debug);
    expect(debugMessage.message, 'debug message');
    expect(debugMessage.logTag, 'LaunchDarkly');

    logger.info('info message');
    final infoMessage =
        (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
    expect(infoMessage.level, LDLogLevel.info);
    expect(infoMessage.message, 'info message');
    expect(infoMessage.logTag, 'LaunchDarkly');

    logger.warn('warn message');
    final warnMessage =
        (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
    expect(warnMessage.level, LDLogLevel.warn);
    expect(warnMessage.message, 'warn message');
    expect(warnMessage.logTag, 'LaunchDarkly');

    logger.error('error message');
    final errorMessage =
        (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
    expect(errorMessage.level, LDLogLevel.error);
    expect(errorMessage.message, 'error message');
    expect(errorMessage.logTag, 'LaunchDarkly');
  });

    test('can set a custom log tag', () {
      final adapter = MockAdapter();
      final logger = LDLogger(
          adapter: adapter, level: LDLogLevel.debug, logTag: 'POTATO');

      logger.debug('debug message');
      final debugMessage =
      (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(debugMessage.logTag, 'POTATO');

      logger.info('info message');
      final infoMessage =
      (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(infoMessage.logTag, 'POTATO');

      logger.warn('warn message');
      final warnMessage =
      (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(warnMessage.logTag, 'POTATO');

      logger.error('error message');
      final errorMessage =
      (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(errorMessage.logTag, 'POTATO');
    });

    test('can make a sub-logger with tag', () {
      final adapter = MockAdapter();
      final baseLogger = LDLogger(
          adapter: adapter, level: LDLogLevel.debug, logTag: 'POTATO');
      final logger = baseLogger.subLogger('CHEESE');

      logger.debug('debug message');
      final debugMessage =
      (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(debugMessage.level, LDLogLevel.debug);
      expect(debugMessage.message, 'debug message');
      expect(debugMessage.logTag, 'POTATO.CHEESE');

      logger.info('info message');
      final infoMessage =
      (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(infoMessage.level, LDLogLevel.info);
      expect(infoMessage.message, 'info message');
      expect(infoMessage.logTag, 'POTATO.CHEESE');

      logger.warn('warn message');
      final warnMessage =
      (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(warnMessage.level, LDLogLevel.warn);
      expect(warnMessage.message, 'warn message');
      expect(warnMessage.logTag, 'POTATO.CHEESE');

      logger.error('error message');
      final errorMessage =
      (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
      expect(errorMessage.level, LDLogLevel.error);
      expect(errorMessage.message, 'error message');
      expect(errorMessage.logTag, 'POTATO.CHEESE');
    });
}
