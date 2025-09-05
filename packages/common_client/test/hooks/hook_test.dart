import 'package:test/test.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'package:launchdarkly_common_client/src/hooks/hook.dart';

void main() {
  group('HookMetadata', () {
    test('toString returns correct format', () {
      final metadata = HookMetadata(name: 'TestHook');
      expect(metadata.toString(), equals('HookMetadata{name: TestHook}'));
    });

    test('toString handles special characters in name', () {
      final metadata = HookMetadata(name: 'Test Hook With Spaces & Special!');
      expect(metadata.toString(),
          equals('HookMetadata{name: Test Hook With Spaces & Special!}'));
    });
  });

  group('EvaluationSeriesContext', () {
    test('toString returns correct format with all fields', () {
      final context = LDContextBuilder().kind('user', 'user-key').build();
      final defaultValue = LDValue.ofString('default');
      final evaluationContext = EvaluationSeriesContext.internal(
        flagKey: 'test-flag',
        context: context,
        defaultValue: defaultValue,
        method: 'boolVariation',
        environmentId: 'env-123',
      );

      final result = evaluationContext.toString();
      expect(result, contains('EvaluationSeriesContext{'));
      expect(result, contains('flagKey: test-flag'));
      expect(result, contains('context: $context'));
      expect(result, contains('defaultValue: $defaultValue'));
      expect(result, contains('method: boolVariation'));
      expect(result, contains('environmentId: env-123'));
    });

    test('toString handles null context and environmentId', () {
      final defaultValue = LDValue.ofString('default');
      final evaluationContext = EvaluationSeriesContext.internal(
        flagKey: 'test-flag',
        context: null,
        defaultValue: defaultValue,
        method: 'stringVariation',
        environmentId: null,
      );

      final result = evaluationContext.toString();
      expect(result, contains('context: null'));
      expect(result, contains('environmentId: null'));
    });
  });

  group('IdentifySeriesContext', () {
    test('toString returns correct format', () {
      final context = LDContextBuilder().kind('user', 'user-key').build();
      final identifyContext = IdentifySeriesContext.internal(context: context);

      expect(identifyContext.toString(),
          equals('IdentifySeriesContext{context: $context}'));
    });

    test('toString with context containing attributes', () {
      final context = LDContextBuilder()
          .kind('user', 'user-key')
          .setString('name', 'Test User')
          .setString('email', 'test@example.com')
          .build();

      final identifyContext = IdentifySeriesContext.internal(context: context);
      expect(identifyContext.toString(),
          equals('IdentifySeriesContext{context: $context}'));
    });
  });

  group('TrackSeriesContext', () {
    test('toString returns correct format with all fields', () {
      final context = LDContextBuilder().kind('user', 'user-key').build();
      final data = LDValue.buildObject()
          .addString('property1', 'value1')
          .addNum('property2', 42)
          .build();

      final trackContext = TrackSeriesContext.internal(
        key: 'custom-event',
        context: context,
        data: data,
        numericValue: 123.45,
      );

      final result = trackContext.toString();
      expect(result, contains('TrackSeriesContext{'));
      expect(result, contains('key: custom-event'));
      expect(result, contains('context: $context'));
      expect(result, contains('data: $data'));
      expect(result, contains('numericValue: 123.45'));
    });

    test('toString handles null data and numericValue', () {
      final context = LDContextBuilder().kind('user', 'user-key').build();
      final trackContext = TrackSeriesContext.internal(
        key: 'simple-event',
        context: context,
        data: null,
        numericValue: null,
      );

      final result = trackContext.toString();
      expect(result, contains('data: null'));
      expect(result, contains('numericValue: null'));
    });

    test('toString with integer numericValue', () {
      final context = LDContextBuilder().kind('user', 'user-key').build();
      final trackContext = TrackSeriesContext.internal(
        key: 'metric-event',
        context: context,
        numericValue: 100,
      );

      final result = trackContext.toString();
      expect(result, contains('numericValue: 100'));
    });
  });
}
