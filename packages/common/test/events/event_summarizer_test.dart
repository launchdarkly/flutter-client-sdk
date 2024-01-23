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

    final summaryEvent = summarizer.createEventAndReset();

    expect(summaryEvent?.startDate.millisecondsSinceEpoch, 1000);
    expect(summaryEvent?.endDate.millisecondsSinceEpoch, 2000);
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

    final summaryEvent = summarizer.createEventAndReset();

    expect(summaryEvent?.features, expectedFeatures);

    final summaryEvent2 = summarizer.createEventAndReset();
    expect(summaryEvent2, isNull);
  });

  test('generates no event if there is nothing to summarize', () {
    final summarizer = EventSummarizer();
    final summaryEvent = summarizer.createEventAndReset();
    expect(summaryEvent, isNull);
  });
}
