import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_dart_common/src/events/event_summarizer.dart';
import 'package:test/test.dart';

void main() {
  final context = LDContextBuilder().kind('user', 'user-key').build();
  test('sets the start and end dates for summary events', () {
    final event1 = EvalEvent(
        flagKey: 'key',
        creationDate: DateTime.fromMillisecondsSinceEpoch(2000),
        defaultValue: LDValue.ofNull(),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value'), 0, LDEvaluationReason.fallthrough()),
        context: context,
        withReason: false,
        trackEvent: false,
        version: 0);
    final event2 = EvalEvent(
        flagKey: 'key',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofNull(),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value'), 0, LDEvaluationReason.fallthrough()),
        context: context,
        withReason: false,
        trackEvent: false,
        version: 0);
    final event3 = EvalEvent(
        flagKey: 'key',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1500),
        defaultValue: LDValue.ofNull(),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value'), 0, LDEvaluationReason.fallthrough()),
        context: context,
        withReason: false,
        trackEvent: false,
        version: 0);

    final summarizer = EventSummarizer();
    summarizer.summarize(event1);
    summarizer.summarize(event2);
    summarizer.summarize(event3);

    final summaryEvents = summarizer.createEventsAndReset();

    expect(summaryEvents.length, 1);
    expect(summaryEvents[0].startDate.millisecondsSinceEpoch, 1000);
    expect(summaryEvents[0].endDate.millisecondsSinceEpoch, 2000);
    expect(summaryEvents[0].context, context);
  });

  test('it increments the correct counters for different evaluations', () {
    final event1 = EvalEvent(
        flagKey: 'key1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofNum(111),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofNum(100), 1, LDEvaluationReason.fallthrough()),
        context: context,
        withReason: false,
        trackEvent: false,
        version: 11);
    final event2 = EvalEvent(
        flagKey: 'key1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofNum(111),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofNum(200), 2, LDEvaluationReason.fallthrough()),
        context: context,
        withReason: false,
        trackEvent: false,
        version: 11);
    final event3 = EvalEvent(
        flagKey: 'key2',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofNum(222),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofNum(999), 1, LDEvaluationReason.fallthrough()),
        context: context,
        withReason: false,
        trackEvent: false,
        version: 22);
    final event4 = EvalEvent(
        flagKey: 'key1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofNum(111),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofNum(100), 1, LDEvaluationReason.fallthrough()),
        context: context,
        withReason: false,
        trackEvent: false,
        version: 11);
    final event5 = EvalEvent(
        flagKey: 'badkey',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofNum(333),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofNum(333), null, LDEvaluationReason.flagNotFound()),
        context: context,
        withReason: false,
        trackEvent: false);
    final event6 = EvalEvent(
        flagKey: 'zero-version',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofNum(444),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofNum(100), 1, LDEvaluationReason.fallthrough()),
        context: context,
        withReason: false,
        trackEvent: false,
        version: 0);

    final summarizer = EventSummarizer();
    summarizer.summarize(event1);
    summarizer.summarize(event2);
    summarizer.summarize(event3);
    summarizer.summarize(event4);
    summarizer.summarize(event5);
    summarizer.summarize(event6);

    final expectedFeatures = <String, FlagSummary>{
      'zero-version': FlagSummary(defaultValue: LDValue.ofNum(444), counters: [
        FlagCounter(
            value: LDValue.ofNum(100), count: 1, version: 0, variation: 1)
      ], contextKinds: [
        'user'
      ]),
      'key1': FlagSummary(defaultValue: LDValue.ofNum(111), counters: [
        FlagCounter(
            value: LDValue.ofNum(100), count: 2, version: 11, variation: 1),
        FlagCounter(
            value: LDValue.ofNum(200), count: 1, version: 11, variation: 2)
      ], contextKinds: [
        'user'
      ]),
      'key2': FlagSummary(defaultValue: LDValue.ofNum(222), counters: [
        FlagCounter(
            value: LDValue.ofNum(999), count: 1, version: 22, variation: 1),
      ], contextKinds: [
        'user'
      ]),
      'badkey': FlagSummary(defaultValue: LDValue.ofNum(333), counters: [
        FlagCounter(value: LDValue.ofNum(333), count: 1, unknown: true),
      ], contextKinds: [
        'user'
      ])
    };

    final summaryEvents = summarizer.createEventsAndReset();

    expect(summaryEvents.length, 1);
    expect(summaryEvents[0].features, expectedFeatures);
    expect(summaryEvents[0].context, context);

    final summaryEvents2 = summarizer.createEventsAndReset();
    expect(summaryEvents2, isEmpty);
  });

  test('generates no event if there is nothing to summarize', () {
    final summarizer = EventSummarizer();
    final summaryEvents = summarizer.createEventsAndReset();
    expect(summaryEvents, isEmpty);
  });

  test('generates separate summary events for different contexts', () {
    final contextA = LDContextBuilder().kind('user', 'user-a').build();
    final contextB = LDContextBuilder().kind('user', 'user-b').build();

    final event1 = EvalEvent(
        flagKey: 'flag1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofString('default'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value-a'), 0, LDEvaluationReason.fallthrough()),
        context: contextA,
        withReason: false,
        trackEvent: false,
        version: 1);
    final event2 = EvalEvent(
        flagKey: 'flag1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1500),
        defaultValue: LDValue.ofString('default'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value-b'), 1, LDEvaluationReason.fallthrough()),
        context: contextB,
        withReason: false,
        trackEvent: false,
        version: 1);
    final event3 = EvalEvent(
        flagKey: 'flag2',
        creationDate: DateTime.fromMillisecondsSinceEpoch(2000),
        defaultValue: LDValue.ofString('default2'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value-a2'), 0, LDEvaluationReason.fallthrough()),
        context: contextA,
        withReason: false,
        trackEvent: false,
        version: 2);

    final summarizer = EventSummarizer();
    summarizer.summarize(event1);
    summarizer.summarize(event2);
    summarizer.summarize(event3);

    final summaryEvents = summarizer.createEventsAndReset();

    expect(summaryEvents.length, 2);

    // Find events by context
    final eventForA = summaryEvents.firstWhere((e) => e.context == contextA);
    final eventForB = summaryEvents.firstWhere((e) => e.context == contextB);

    // Verify contextA summary
    expect(eventForA.startDate.millisecondsSinceEpoch, 1000);
    expect(eventForA.endDate.millisecondsSinceEpoch, 2000);
    expect(eventForA.features.keys, containsAll(['flag1', 'flag2']));

    // Verify contextB summary
    expect(eventForB.startDate.millisecondsSinceEpoch, 1500);
    expect(eventForB.endDate.millisecondsSinceEpoch, 1500);
    expect(eventForB.features.keys, contains('flag1'));
    expect(eventForB.features.keys, isNot(contains('flag2')));
  });

  test('aggregates events from same context into single summary', () {
    final contextA = LDContextBuilder().kind('user', 'user-a').build();

    final event1 = EvalEvent(
        flagKey: 'flag1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofString('default'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value'), 0, LDEvaluationReason.fallthrough()),
        context: contextA,
        withReason: false,
        trackEvent: false,
        version: 1);
    final event2 = EvalEvent(
        flagKey: 'flag1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(2000),
        defaultValue: LDValue.ofString('default'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value'), 0, LDEvaluationReason.fallthrough()),
        context: contextA,
        withReason: false,
        trackEvent: false,
        version: 1);

    final summarizer = EventSummarizer();
    summarizer.summarize(event1);
    summarizer.summarize(event2);

    final summaryEvents = summarizer.createEventsAndReset();

    expect(summaryEvents.length, 1);
    expect(summaryEvents[0].context, contextA);
    expect(summaryEvents[0].features['flag1']?.counters[0].count, 2);
  });

  test('skips invalid contexts', () {
    final validContext = LDContextBuilder().kind('user', 'user-a').build();
    final invalidContext =
        LDContextBuilder().build(); // No kind specified = invalid

    final validEvent = EvalEvent(
        flagKey: 'flag1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofString('default'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value'), 0, LDEvaluationReason.fallthrough()),
        context: validContext,
        withReason: false,
        trackEvent: false,
        version: 1);
    final invalidEvent = EvalEvent(
        flagKey: 'flag2',
        creationDate: DateTime.fromMillisecondsSinceEpoch(2000),
        defaultValue: LDValue.ofString('default'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value'), 0, LDEvaluationReason.fallthrough()),
        context: invalidContext,
        withReason: false,
        trackEvent: false,
        version: 1);

    final summarizer = EventSummarizer();
    summarizer.summarize(validEvent);
    summarizer.summarize(invalidEvent);

    final summaryEvents = summarizer.createEventsAndReset();

    expect(summaryEvents.length, 1);
    expect(summaryEvents[0].context, validContext);
    expect(summaryEvents[0].features.keys, contains('flag1'));
    expect(summaryEvents[0].features.keys, isNot(contains('flag2')));
  });

  test('handles contexts with same keys but different attributes', () {
    final contextA = LDContextBuilder()
        .kind('user', 'user-key')
        .setString('name', 'Alice')
        .build();
    final contextB = LDContextBuilder()
        .kind('user', 'user-key')
        .setString('name', 'Bob')
        .build();

    final event1 = EvalEvent(
        flagKey: 'flag1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofString('default'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value-a'), 0, LDEvaluationReason.fallthrough()),
        context: contextA,
        withReason: false,
        trackEvent: false,
        version: 1);
    final event2 = EvalEvent(
        flagKey: 'flag1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(2000),
        defaultValue: LDValue.ofString('default'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value-b'), 1, LDEvaluationReason.fallthrough()),
        context: contextB,
        withReason: false,
        trackEvent: false,
        version: 1);

    final summarizer = EventSummarizer();
    summarizer.summarize(event1);
    summarizer.summarize(event2);

    final summaryEvents = summarizer.createEventsAndReset();

    // Should create 2 separate summary events since contexts differ in attributes
    expect(summaryEvents.length, 2);
  });

  test(
      'with summariesPerContext disabled, generates single summary without context',
      () {
    final contextA = LDContextBuilder().kind('user', 'user-a').build();
    final contextB = LDContextBuilder().kind('user', 'user-b').build();

    final event1 = EvalEvent(
        flagKey: 'flag1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofString('default'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value-a'), 0, LDEvaluationReason.fallthrough()),
        context: contextA,
        withReason: false,
        trackEvent: false,
        version: 1);
    final event2 = EvalEvent(
        flagKey: 'flag1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1500),
        defaultValue: LDValue.ofString('default'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value-a'), 0, LDEvaluationReason.fallthrough()),
        context: contextB,
        withReason: false,
        trackEvent: false,
        version: 1);

    final summarizer = EventSummarizer(summariesPerContext: false);
    summarizer.summarize(event1);
    summarizer.summarize(event2);

    final summaryEvents = summarizer.createEventsAndReset();

    // Should create only 1 summary event aggregating all contexts
    expect(summaryEvents.length, 1);

    // Context should not be included when per-context is disabled
    expect(summaryEvents[0].context, isNull);

    // Both evaluations should be aggregated (same flag, variation, version)
    expect(summaryEvents[0].features['flag1']?.counters[0].count, 2);
  });

  test('with summariesPerContext disabled, aggregates different flags', () {
    final contextA = LDContextBuilder().kind('user', 'user-a').build();
    final contextB = LDContextBuilder().kind('user', 'user-b').build();

    final event1 = EvalEvent(
        flagKey: 'flag1',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        defaultValue: LDValue.ofString('default1'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value1'), 0, LDEvaluationReason.fallthrough()),
        context: contextA,
        withReason: false,
        trackEvent: false,
        version: 1);
    final event2 = EvalEvent(
        flagKey: 'flag2',
        creationDate: DateTime.fromMillisecondsSinceEpoch(2000),
        defaultValue: LDValue.ofString('default2'),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofString('value2'), 1, LDEvaluationReason.fallthrough()),
        context: contextB,
        withReason: false,
        trackEvent: false,
        version: 2);

    final summarizer = EventSummarizer(summariesPerContext: false);
    summarizer.summarize(event1);
    summarizer.summarize(event2);

    final summaryEvents = summarizer.createEventsAndReset();

    // Should create only 1 summary event
    expect(summaryEvents.length, 1);
    expect(summaryEvents[0].context, isNull);

    // Should have both flags in the summary
    expect(summaryEvents[0].features.keys, containsAll(['flag1', 'flag2']));
    expect(summaryEvents[0].features['flag1']?.counters[0].count, 1);
    expect(summaryEvents[0].features['flag2']?.counters[0].count, 1);
  });
}
