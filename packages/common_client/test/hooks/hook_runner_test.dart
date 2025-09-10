import 'dart:collection';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'package:launchdarkly_common_client/src/hooks/hook.dart';
import 'package:launchdarkly_common_client/src/hooks/hook_runner.dart';
import 'package:launchdarkly_common_client/src/ld_common_client.dart';

class MockLogAdapter extends Mock implements LDLogAdapter {}

final class TestHook extends Hook {
  final List<String> callLog = [];
  final Map<String, dynamic> dataToReturn;
  final bool shouldThrow;
  final String? errorMessage;
  final List<UnmodifiableMapView<String, dynamic>> receivedBeforeData = [];
  final List<UnmodifiableMapView<String, dynamic>> receivedAfterData = [];
  final HookMetadata _metadata;

  // For tracking execution order across multiple hooks
  static final List<String> globalExecutionOrder = [];

  @override
  HookMetadata get metadata => _metadata;

  TestHook({
    required String name,
    this.dataToReturn = const {},
    this.shouldThrow = false,
    this.errorMessage,
  })  : _metadata = HookMetadata(name: name),
        super();

  void clearGlobalOrder() {
    globalExecutionOrder.clear();
  }

  @override
  UnmodifiableMapView<String, dynamic> beforeEvaluation(
    EvaluationSeriesContext hookContext,
    UnmodifiableMapView<String, dynamic> data,
  ) {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error in beforeEvaluation');
    }
    callLog.add('beforeEvaluation');
    globalExecutionOrder.add('${metadata.name}-before');
    receivedBeforeData.add(data);
    final newData = Map<String, dynamic>.from(data);
    newData.addAll(dataToReturn);
    return UnmodifiableMapView(newData);
  }

  @override
  UnmodifiableMapView<String, dynamic> afterEvaluation(
    EvaluationSeriesContext hookContext,
    UnmodifiableMapView<String, dynamic> data,
    LDEvaluationDetail<LDValue> detail,
  ) {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error in afterEvaluation');
    }
    callLog.add('afterEvaluation');
    globalExecutionOrder.add('${metadata.name}-after');
    receivedAfterData.add(data);
    return data;
  }

  @override
  UnmodifiableMapView<String, dynamic> beforeIdentify(
    IdentifySeriesContext hookContext,
    UnmodifiableMapView<String, dynamic> data,
  ) {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error in beforeIdentify');
    }
    callLog.add('beforeIdentify');
    globalExecutionOrder.add('${metadata.name}-beforeIdentify');
    final newData = Map<String, dynamic>.from(data);
    newData.addAll(dataToReturn);
    return UnmodifiableMapView(newData);
  }

  @override
  UnmodifiableMapView<String, dynamic> afterIdentify(
    IdentifySeriesContext hookContext,
    UnmodifiableMapView<String, dynamic> data,
    IdentifyResult result,
  ) {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error in afterIdentify');
    }
    callLog.add('afterIdentify');
    globalExecutionOrder.add('${metadata.name}-afterIdentify');
    return data;
  }

  @override
  void afterTrack(TrackSeriesContext hookContext) {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error in afterTrack');
    }
    callLog.add('afterTrack');
  }
}

void main() {
  late LDLogger logger;
  late MockLogAdapter mockLogAdapter;
  late HookRunner hookRunner;

  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });

  setUp(() {
    mockLogAdapter = MockLogAdapter();
    logger = LDLogger(adapter: mockLogAdapter);
    hookRunner = HookRunner(logger);
  });

  group('HookRunner', () {
    test('should execute hooks for evaluation', () {
      final hook1 = TestHook(name: 'hook1');
      final hook2 = TestHook(name: 'hook2');
      hookRunner.addHook(hook1);
      hookRunner.addHook(hook2);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final defaultValue = LDValue.ofString('default');
      var evaluationCalled = false;

      final result = hookRunner.withEvaluation(
        'test-flag',
        context,
        defaultValue,
        VariationMethodNames.stringVariation,
        () {
          evaluationCalled = true;
          return LDEvaluationDetail(
            LDValue.ofString('test-value'),
            0,
            LDEvaluationReason.flagNotFound(),
          );
        },
      );

      expect(evaluationCalled, isTrue);
      expect(result.value.stringValue(), equals('test-value'));
      expect(hook1.callLog, equals(['beforeEvaluation', 'afterEvaluation']));
      expect(hook2.callLog, equals(['beforeEvaluation', 'afterEvaluation']));
    });

    test('should handle empty hooks list', () {
      final context = LDContextBuilder().kind('user', 'test-user').build();
      final defaultValue = LDValue.ofString('default');
      var evaluationCalled = false;

      final result = hookRunner.withEvaluation(
        'test-flag',
        context,
        defaultValue,
        VariationMethodNames.stringVariation,
        () {
          evaluationCalled = true;
          return LDEvaluationDetail(
            LDValue.ofString('test-value'),
            0,
            LDEvaluationReason.flagNotFound(),
          );
        },
      );

      expect(evaluationCalled, isTrue);
      expect(result.value.stringValue(), equals('test-value'));
    });

    test('should handle hook errors gracefully in beforeEvaluation', () {
      final errorHook = TestHook(
        name: 'error-hook',
        shouldThrow: true,
        errorMessage: 'beforeEvaluation error',
      );
      final normalHook = TestHook(name: 'normal-hook');

      hookRunner.addHook(errorHook);
      hookRunner.addHook(normalHook);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final defaultValue = LDValue.ofString('default');
      var evaluationCalled = false;

      final result = hookRunner.withEvaluation(
        'test-flag',
        context,
        defaultValue,
        VariationMethodNames.stringVariation,
        () {
          evaluationCalled = true;
          return LDEvaluationDetail(
            LDValue.ofString('test-value'),
            0,
            LDEvaluationReason.flagNotFound(),
          );
        },
      );

      expect(evaluationCalled, isTrue);
      expect(result.value.stringValue(), equals('test-value'));

      // Normal hook should still execute
      expect(
          normalHook.callLog, equals(['beforeEvaluation', 'afterEvaluation']));

      // Verify error messages were logged
      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.error &&
              record.message.contains(
                  'An error was encountered in "beforeEvaluation" of the "error-hook" hook') &&
              record.message.contains('beforeEvaluation error'))))).called(1);

      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.error &&
              record.message.contains(
                  'An error was encountered in "afterEvaluation" of the "error-hook" hook') &&
              record.message.contains('beforeEvaluation error'))))).called(1);
    });

    test('should pass data between hooks in correct order', () {
      final hook1 = TestHook(
        name: 'hook1',
        dataToReturn: {'hook1-key': LDValue.ofString('hook1-value')},
      );
      final hook2 = TestHook(
        name: 'hook2',
        dataToReturn: {'hook2-key': LDValue.ofString('hook2-value')},
      );

      hookRunner.addHook(hook1);
      hookRunner.addHook(hook2);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final defaultValue = LDValue.ofString('default');

      hookRunner.withEvaluation(
        'test-flag',
        context,
        defaultValue,
        VariationMethodNames.stringVariation,
        () => LDEvaluationDetail(
          LDValue.ofString('test-value'),
          0,
          LDEvaluationReason.flagNotFound(),
        ),
      );

      // Verify execution order: beforeEvaluation in forward order, afterEvaluation in reverse order
      expect(hook1.callLog, equals(['beforeEvaluation', 'afterEvaluation']));
      expect(hook2.callLog, equals(['beforeEvaluation', 'afterEvaluation']));

      // Verify data flow: hook1 receives empty data, hook2 receives hook1's data
      expect(hook1.receivedBeforeData.first.keys, isEmpty);
      expect(hook2.receivedBeforeData.first['hook1-key']?.stringValue(),
          equals('hook1-value'));

      // Verify afterEvaluation receives the correct data from corresponding beforeEvaluation
      expect(hook1.receivedAfterData.first['hook1-key']?.stringValue(),
          equals('hook1-value'));
      expect(hook2.receivedAfterData.first['hook1-key']?.stringValue(),
          equals('hook1-value'));
      expect(hook2.receivedAfterData.first['hook2-key']?.stringValue(),
          equals('hook2-value'));
    });

    test(
        'should execute hooks in correct order (before forward, after reverse) for evaluation series',
        () {
      final hook1 = TestHook(name: 'hook1');
      final hook2 = TestHook(name: 'hook2');
      final hook3 = TestHook(name: 'hook3');

      // Clear global order tracking
      TestHook.globalExecutionOrder.clear();

      hookRunner.addHook(hook1);
      hookRunner.addHook(hook2);
      hookRunner.addHook(hook3);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final defaultValue = LDValue.ofString('default');

      hookRunner.withEvaluation(
        'test-flag',
        context,
        defaultValue,
        VariationMethodNames.stringVariation,
        () => LDEvaluationDetail(
          LDValue.ofString('test-value'),
          0,
          LDEvaluationReason.flagNotFound(),
        ),
      );

      // Check that all hooks were called
      expect(hook1.callLog, equals(['beforeEvaluation', 'afterEvaluation']));
      expect(hook2.callLog, equals(['beforeEvaluation', 'afterEvaluation']));
      expect(hook3.callLog, equals(['beforeEvaluation', 'afterEvaluation']));

      // Verify execution order: before should be forward (1,2,3), after should be reverse (3,2,1)
      expect(
          TestHook.globalExecutionOrder,
          equals([
            'hook1-before',
            'hook2-before',
            'hook3-before',
            'hook3-after',
            'hook2-after',
            'hook1-after'
          ]));
    });

    test('should pass evaluation series data from before to after hooks', () {
      final hook = TestHook(
        name: 'test-hook',
        dataToReturn: {'testData': LDValue.ofString('before data')},
      );

      hookRunner.addHook(hook);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final defaultValue = LDValue.ofString('default');

      final result = hookRunner.withEvaluation(
        'test-flag',
        context,
        defaultValue,
        VariationMethodNames.stringVariation,
        () => LDEvaluationDetail(
          LDValue.ofString('test-value'),
          0,
          LDEvaluationReason.flagNotFound(),
        ),
      );

      expect(result.value.stringValue(), equals('test-value'));

      // Verify data flow: beforeEvaluation adds data, afterEvaluation receives it
      expect(hook.receivedBeforeData.first.keys,
          isEmpty); // starts with empty data
      expect(hook.receivedAfterData.first['testData']?.stringValue(),
          equals('before data'));
    });

    test('should execute identify hooks', () {
      final hook = TestHook(name: 'test-hook');
      hookRunner.addHook(hook);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final afterIdentifyCallback = hookRunner.identify(context);

      afterIdentifyCallback(IdentifyComplete());

      expect(hook.callLog, equals(['beforeIdentify', 'afterIdentify']));
    });

    test('should handle identify hook errors', () {
      final errorHook = TestHook(
        name: 'error-hook',
        shouldThrow: true,
        errorMessage: 'identify error',
      );
      hookRunner.addHook(errorHook);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final afterIdentifyCallback = hookRunner.identify(context);

      afterIdentifyCallback(IdentifyComplete());

      // Verify error messages were logged for both stages
      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.error &&
              record.message.contains(
                  'An error was encountered in "beforeIdentify" of the "error-hook" hook') &&
              record.message.contains('identify error'))))).called(1);

      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.error &&
              record.message.contains(
                  'An error was encountered in "afterIdentify" of the "error-hook" hook') &&
              record.message.contains('identify error'))))).called(1);
    });

    test(
        'should execute hooks in correct order (before forward, after reverse) for identify series',
        () {
      final hook1 = TestHook(name: 'hook1');
      final hook2 = TestHook(name: 'hook2');
      final hook3 = TestHook(name: 'hook3');

      // Clear global order tracking
      TestHook.globalExecutionOrder.clear();

      hookRunner.addHook(hook1);
      hookRunner.addHook(hook2);
      hookRunner.addHook(hook3);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final afterIdentifyCallback = hookRunner.identify(context);

      afterIdentifyCallback(IdentifyComplete());

      // Check that all hooks were called
      expect(hook1.callLog, equals(['beforeIdentify', 'afterIdentify']));
      expect(hook2.callLog, equals(['beforeIdentify', 'afterIdentify']));
      expect(hook3.callLog, equals(['beforeIdentify', 'afterIdentify']));

      // Verify execution order: beforeIdentify should be forward (1,2,3), afterIdentify should be reverse (3,2,1)
      expect(
          TestHook.globalExecutionOrder,
          equals([
            'hook1-beforeIdentify',
            'hook2-beforeIdentify',
            'hook3-beforeIdentify',
            'hook3-afterIdentify',
            'hook2-afterIdentify',
            'hook1-afterIdentify'
          ]));
    });

    test('should execute afterTrack hooks', () {
      final hook = TestHook(name: 'test-hook');
      hookRunner.addHook(hook);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final trackContext = TrackSeriesContext.internal(
        key: 'test-event',
        context: context,
        data: LDValue.ofString('event-data'),
        numericValue: 42.0,
      );

      hookRunner.afterTrack(trackContext);

      expect(hook.callLog, equals(['afterTrack']));
    });

    test('should handle afterTrack hook errors', () {
      final errorHook = TestHook(
        name: 'error-hook',
        shouldThrow: true,
        errorMessage: 'track error',
      );
      hookRunner.addHook(errorHook);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final trackContext = TrackSeriesContext.internal(
        key: 'test-event',
        context: context,
      );

      hookRunner.afterTrack(trackContext);

      // Verify error message was logged
      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.error &&
              record.message.contains(
                  'An error was encountered in "afterTrack" of the "error-hook" hook') &&
              record.message.contains('track error'))))).called(1);
    });

    test('should support initial hooks in constructor', () {
      final hook1 = TestHook(name: 'hook1');
      final hook2 = TestHook(name: 'hook2');
      final testLogger = LDLogger(adapter: MockLogAdapter());
      final runnerWithInitialHooks = HookRunner(testLogger, [hook1, hook2]);

      final context = LDContextBuilder().kind('user', 'test-user').build();
      final defaultValue = LDValue.ofString('default');

      runnerWithInitialHooks.withEvaluation(
        'test-flag',
        context,
        defaultValue,
        VariationMethodNames.stringVariation,
        () => LDEvaluationDetail(
          LDValue.ofString('test-value'),
          0,
          LDEvaluationReason.flagNotFound(),
        ),
      );

      expect(hook1.callLog, equals(['beforeEvaluation', 'afterEvaluation']));
      expect(hook2.callLog, equals(['beforeEvaluation', 'afterEvaluation']));
    });

    test('should handle null context in evaluation', () {
      final hook = TestHook(name: 'test-hook');
      hookRunner.addHook(hook);

      final defaultValue = LDValue.ofString('default');
      var evaluationCalled = false;

      final result = hookRunner.withEvaluation(
        'test-flag',
        null, // null context
        defaultValue,
        VariationMethodNames.stringVariation,
        () {
          evaluationCalled = true;
          return LDEvaluationDetail(
            LDValue.ofString('test-value'),
            0,
            LDEvaluationReason.flagNotFound(),
          );
        },
      );

      expect(evaluationCalled, isTrue);
      expect(result.value.stringValue(), equals('test-value'));
      expect(hook.callLog, equals(['beforeEvaluation', 'afterEvaluation']));
    });
  });
}
