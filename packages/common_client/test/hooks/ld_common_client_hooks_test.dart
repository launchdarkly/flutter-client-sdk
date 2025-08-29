import 'dart:collection';
import 'package:test/test.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

import '../ld_dart_client_test.dart' show TestConfig;

final class TestHook extends Hook {
  final List<String> callLog = [];
  final List<EvaluationSeriesContext> evaluationContexts = [];
  final List<IdentifySeriesContext> identifyContexts = [];
  final List<TrackSeriesContext> trackContexts = [];
  final List<IdentifyResult> identifyResults = [];
  final List<LDEvaluationDetail<LDValue>> evaluationResults = [];

  TestHook(String name) : super(HookMetadata(name: name));

  @override
  UnmodifiableMapView<String, LDValue> beforeEvaluation(
    EvaluationSeriesContext hookContext,
    UnmodifiableMapView<String, LDValue> data,
  ) {
    callLog.add('beforeEvaluation');
    evaluationContexts.add(hookContext);
    return data;
  }

  @override
  UnmodifiableMapView<String, LDValue> afterEvaluation(
    EvaluationSeriesContext hookContext,
    UnmodifiableMapView<String, LDValue> data,
    LDEvaluationDetail<LDValue> detail,
  ) {
    callLog.add('afterEvaluation');
    evaluationContexts.add(hookContext);
    evaluationResults.add(detail);
    return data;
  }

  @override
  UnmodifiableMapView<String, LDValue> beforeIdentify(
    IdentifySeriesContext hookContext,
    UnmodifiableMapView<String, LDValue> data,
  ) {
    callLog.add('beforeIdentify');
    identifyContexts.add(hookContext);
    return data;
  }

  @override
  UnmodifiableMapView<String, LDValue> afterIdentify(
    IdentifySeriesContext hookContext,
    UnmodifiableMapView<String, LDValue> data,
    IdentifyResult result,
  ) {
    callLog.add('afterIdentify');
    identifyContexts.add(hookContext);
    identifyResults.add(result);
    return data;
  }

  @override
  void afterTrack(TrackSeriesContext hookContext) {
    callLog.add('afterTrack');
    trackContexts.add(hookContext);
  }
}

void main() {
  group('LDCommonClient Hooks Integration', () {
    late LDCommonClient client;
    late TestHook initialHook;
    late LDContext testContext;

    setUp(() {
      initialHook = TestHook('initial-hook');
      testContext = LDContextBuilder().kind('user', 'test-user').build();

      client = LDCommonClient(
        TestConfig('test-sdk-key', AutoEnvAttributes.disabled, offline: true),
        CommonPlatform(),
        testContext,
        DiagnosticSdkData(name: 'test-sdk', version: '1.0.0'),
        hooks: [initialHook],
      );
    });

    tearDown(() async {
      await client.close();
    });

    test('should use hooks registered during configuration', () async {
      await client.start();

      // Test flag evaluation
      client.boolVariation('test-flag', false);

      expect(initialHook.callLog, contains('beforeEvaluation'));
      expect(initialHook.callLog, contains('afterEvaluation'));
      expect(initialHook.evaluationContexts.isNotEmpty, isTrue);
      expect(initialHook.evaluationContexts.first.flagKey, equals('test-flag'));
      expect(
          initialHook.evaluationContexts.first.method, equals('boolVariation'));

      // Test identify
      initialHook.callLog.clear();
      await client.identify(testContext);

      expect(initialHook.callLog, contains('beforeIdentify'));
      expect(initialHook.callLog, contains('afterIdentify'));
      expect(initialHook.identifyContexts.isNotEmpty, isTrue);
      expect(initialHook.identifyResults.isNotEmpty, isTrue);
      expect(initialHook.identifyResults.first, isA<IdentifyComplete>());
    });

    test('should execute hooks that are added using addHook', () async {
      final dynamicHook = TestHook('dynamic-hook');
      await client.start();

      client.addHook(dynamicHook);

      // Test flag evaluation
      client.stringVariation('test-flag', 'default');

      expect(dynamicHook.callLog, contains('beforeEvaluation'));
      expect(dynamicHook.callLog, contains('afterEvaluation'));
      expect(dynamicHook.evaluationContexts.first.flagKey, equals('test-flag'));
      expect(dynamicHook.evaluationContexts.first.method,
          equals('stringVariation'));

      // Test identify
      dynamicHook.callLog.clear();
      await client.identify(testContext);

      expect(dynamicHook.callLog, contains('beforeIdentify'));
      expect(dynamicHook.callLog, contains('afterIdentify'));
    });

    test('should execute both initial hooks and hooks added using addHook',
        () async {
      final dynamicHook = TestHook('dynamic-hook');
      await client.start();

      client.addHook(dynamicHook);

      // Test flag evaluation
      client.intVariation('test-flag', 0);

      // Both hooks should be called
      expect(initialHook.callLog, contains('beforeEvaluation'));
      expect(initialHook.callLog, contains('afterEvaluation'));
      expect(dynamicHook.callLog, contains('beforeEvaluation'));
      expect(dynamicHook.callLog, contains('afterEvaluation'));

      // Test identify
      initialHook.callLog.clear();
      dynamicHook.callLog.clear();
      await client.identify(testContext);

      expect(initialHook.callLog, contains('beforeIdentify'));
      expect(initialHook.callLog, contains('afterIdentify'));
      expect(dynamicHook.callLog, contains('beforeIdentify'));
      expect(dynamicHook.callLog, contains('afterIdentify'));
    });

    test('should execute afterTrack hooks when tracking events', () async {
      await client.start();

      client.track('test-event',
          data: LDValue.ofString('test-data'), metricValue: 42.0);

      expect(initialHook.callLog, contains('afterTrack'));
      expect(initialHook.trackContexts.isNotEmpty, isTrue);
      expect(initialHook.trackContexts.first.key, equals('test-event'));
      expect(initialHook.trackContexts.first.data?.stringValue(),
          equals('test-data'));
      expect(initialHook.trackContexts.first.numericValue, equals(42.0));
    });

    test('should execute hooks for all variation methods', () async {
      await client.start();

      // Test all variation methods
      client.boolVariation('bool-flag', false);
      client.boolVariationDetail('bool-detail-flag', false);
      client.intVariation('int-flag', 0);
      client.intVariationDetail('int-detail-flag', 0);
      client.doubleVariation('double-flag', 0.0);
      client.doubleVariationDetail('double-detail-flag', 0.0);
      client.stringVariation('string-flag', 'default');
      client.stringVariationDetail('string-detail-flag', 'default');
      client.jsonVariation('json-flag', LDValue.ofNull());
      client.jsonVariationDetail('json-detail-flag', LDValue.ofNull());

      // Should have 20 calls total (10 beforeEvaluation + 10 afterEvaluation)
      final beforeEvaluationCalls = initialHook.callLog
          .where((call) => call == 'beforeEvaluation')
          .length;
      final afterEvaluationCalls =
          initialHook.callLog.where((call) => call == 'afterEvaluation').length;

      expect(beforeEvaluationCalls, equals(10));
      expect(afterEvaluationCalls, equals(10));

      // Check that all method names are captured
      final methods =
          initialHook.evaluationContexts.map((ctx) => ctx.method).toSet();
      expect(
          methods,
          containsAll([
            'boolVariation',
            'boolVariationDetail',
            'intVariation',
            'intVariationDetail',
            'doubleVariation',
            'doubleVariationDetail',
            'stringVariation',
            'stringVariationDetail',
            'jsonVariation',
            'jsonVariationDetail',
          ]));
    });

    test('should pass correct context information to hooks', () async {
      await client.start();

      final defaultValue = LDValue.ofString('test-default');
      client.jsonVariation('context-test-flag', defaultValue);

      expect(initialHook.evaluationContexts.isNotEmpty, isTrue);
      final evalContext = initialHook.evaluationContexts.first;
      expect(evalContext.flagKey, equals('context-test-flag'));
      expect(evalContext.defaultValue, equals(defaultValue));
      expect(evalContext.method, equals('jsonVariation'));
      expect(evalContext.context, isNotNull);
      expect(evalContext.environmentId,
          isNull); // Environment ID not implemented yet
    });

    test('should handle hooks when client is not started', () async {
      // Don't start the client
      client.boolVariation('test-flag', false);

      // Hooks should still be called even if client isn't fully started
      expect(initialHook.callLog, contains('beforeEvaluation'));
      expect(initialHook.callLog, contains('afterEvaluation'));
    });
  });
}
