import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

void main() {
  test('can serialize an identify event', () {
    final event = IdentifyEvent(
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder().kind('user', 'user-key').build());

    final json = jsonEncode(IdentifyEventSerialization.toJson(event,
        allAttributesPrivate: false, globalPrivateAttributes: {}));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "identify",'
        '"creationDate": 0,'
        '"context": {'
        '"kind": "user",'
        '"key": "user-key"'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize an identify event with all attributes private', () {
    final event = IdentifyEvent(
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder()
            .kind('user', 'user-key')
            .name('the-name')
            .set('custom', LDValue.ofString('custom'))
            .build());

    final json = jsonEncode(IdentifyEventSerialization.toJson(event,
        allAttributesPrivate: true, globalPrivateAttributes: {}));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "identify",'
        '"creationDate": 0,'
        '"context": {'
        '"kind": "user",'
        '"key": "user-key",'
        '"_meta": {"redactedAttributes":["/name", "/custom"]}'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize an identify event with global private attributes', () {
    final event = IdentifyEvent(
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder()
            .kind('user', 'user-key')
            .name('the-name')
            .set('custom', LDValue.ofString('custom'))
            .build());

    final json = jsonEncode(IdentifyEventSerialization.toJson(event,
        allAttributesPrivate: false,
        globalPrivateAttributes: {AttributeReference('/custom')}));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "identify",'
        '"creationDate": 0,'
        '"context": {'
        '"kind": "user",'
        '"name": "the-name",'
        '"key": "user-key",'
        '"_meta": {"redactedAttributes":["/custom"]}'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize custom event without data or metricValue', () {
    final event = CustomEvent(
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder().kind('user', 'user-key').build(),
        key: 'my-key');

    final json = jsonEncode(CustomEventSerialization.toJson(event));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "custom",'
        '"key": "my-key",'
        '"creationDate": 0,'
        '"contextKeys": {'
        '"user": "user-key"'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize custom event with metric value', () {
    final event = CustomEvent(
        metricValue: 100,
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder().kind('user', 'user-key').build(),
        key: 'my-key');

    final json = jsonEncode(CustomEventSerialization.toJson(event));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "custom",'
        '"metricValue": 100,'
        '"key": "my-key",'
        '"creationDate": 0,'
        '"contextKeys": {'
        '"user": "user-key"'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize custom event with data', () {
    final event = CustomEvent(
        data: LDValue.buildObject().addString('test', 'value').build(),
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder().kind('user', 'user-key').build(),
        key: 'my-key');

    final json = jsonEncode(CustomEventSerialization.toJson(event));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "custom",'
        '"key": "my-key",'
        '"data": {"test": "value"},'
        '"creationDate": 0,'
        '"contextKeys": {'
        '"user": "user-key"'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize custom event with data and metric event', () {
    final event = CustomEvent(
        data: LDValue.buildObject().addString('test', 'value').build(),
        metricValue: 100,
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder().kind('user', 'user-key').build(),
        key: 'my-key');

    final json = jsonEncode(CustomEventSerialization.toJson(event));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "custom",'
        '"key": "my-key",'
        '"data": {"test": "value"},'
        '"metricValue": 100,'
        '"creationDate": 0,'
        '"contextKeys": {'
        '"user": "user-key"'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize feature event for known flag with reason', () {
    final event = EvalEvent(
        version: 42,
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder().kind('user', 'user-key').build(),
        flagKey: 'the-flag',
        defaultValue: LDValue.ofString('default-value'),
        evaluationDetail: LDEvaluationDetail(LDValue.ofString('the-value'), 10,
            LDEvaluationReason.fallthrough()),
        withReason: true,
        trackEvent: false);

    final json = jsonEncode(EvalEventSerialization.toJson(event,
        allAttributesPrivate: false, globalPrivateAttributes: {}));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "feature",'
        '"key": "the-flag",'
        '"version": 42,'
        '"creationDate": 0,'
        '"default": "default-value",'
        '"variation": 10,'
        '"value": "the-value",'
        '"reason": {"kind": "FALLTHROUGH"},'
        '"contextKeys": {'
        '"user": "user-key"'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize feature event for known flag without reason', () {
    final event = EvalEvent(
        version: 42,
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder().kind('user', 'user-key').build(),
        flagKey: 'the-flag',
        defaultValue: LDValue.ofString('default-value'),
        evaluationDetail: LDEvaluationDetail(LDValue.ofString('the-value'), 10,
            LDEvaluationReason.fallthrough()),
        withReason: false,
        trackEvent: false);

    final json = jsonEncode(EvalEventSerialization.toJson(event,
        allAttributesPrivate: false, globalPrivateAttributes: {}));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "feature",'
        '"key": "the-flag",'
        '"version": 42,'
        '"creationDate": 0,'
        '"default": "default-value",'
        '"variation": 10,'
        '"value": "the-value",'
        '"contextKeys": {'
        '"user": "user-key"'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize feature event for unknown flag', () {
    final event = EvalEvent(
        version: null,
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder().kind('user', 'user-key').build(),
        flagKey: 'the-flag',
        defaultValue: LDValue.ofString('default-value'),
        evaluationDetail: LDEvaluationDetail(LDValue.ofString('the-value'),
            null, LDEvaluationReason.flagNotFound()),
        withReason: true,
        trackEvent: false);

    final json = jsonEncode(EvalEventSerialization.toJson(event,
        allAttributesPrivate: false, globalPrivateAttributes: {}));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "feature",'
        '"key": "the-flag",'
        '"creationDate": 0,'
        '"default": "default-value",'
        '"value": "the-value",'
        '"reason": {"kind": "ERROR", "errorKind": "FLAG_NOT_FOUND"},'
        '"contextKeys": {'
        '"user": "user-key"'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize debug event', () {
    final event = EvalEvent(
        version: 42,
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder().kind('user', 'user-key').build(),
        flagKey: 'the-flag',
        defaultValue: LDValue.ofString('default-value'),
        evaluationDetail: LDEvaluationDetail(LDValue.ofString('the-value'), 10,
            LDEvaluationReason.fallthrough()),
        withReason: true,
        trackEvent: false);

    final json = jsonEncode(EvalEventSerialization.toJson(event,
        isDebug: true,
        allAttributesPrivate: false,
        globalPrivateAttributes: {}));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "debug",'
        '"key": "the-flag",'
        '"version": 42,'
        '"creationDate": 0,'
        '"default": "default-value",'
        '"variation": 10,'
        '"value": "the-value",'
        '"reason": {"kind": "FALLTHROUGH"},'
        '"context": {'
        '"kind": "user",'
        '"key": "user-key"'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize debug event with all attributes private', () {
    final event = EvalEvent(
        version: 42,
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder()
            .kind('user', 'user-key')
            .name('the-name')
            .set('custom', LDValue.ofString('custom'))
            .build(),
        flagKey: 'the-flag',
        defaultValue: LDValue.ofString('default-value'),
        evaluationDetail: LDEvaluationDetail(LDValue.ofString('the-value'), 10,
            LDEvaluationReason.fallthrough()),
        withReason: true,
        trackEvent: false);

    final json = jsonEncode(EvalEventSerialization.toJson(event,
        isDebug: true,
        allAttributesPrivate: true,
        globalPrivateAttributes: {}));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "debug",'
        '"key": "the-flag",'
        '"version": 42,'
        '"creationDate": 0,'
        '"default": "default-value",'
        '"variation": 10,'
        '"value": "the-value",'
        '"reason": {"kind": "FALLTHROUGH"},'
        '"context": {'
        '"kind": "user",'
        '"key": "user-key",'
        '"_meta": {"redactedAttributes":["/name", "/custom"]}'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize debug event with global private attributes', () {
    final event = EvalEvent(
        version: 42,
        creationDate: DateTime.fromMillisecondsSinceEpoch(0),
        context: LDContextBuilder()
            .kind('user', 'user-key')
            .name('the-name')
            .set('custom', LDValue.ofString('custom'))
            .build(),
        flagKey: 'the-flag',
        defaultValue: LDValue.ofString('default-value'),
        evaluationDetail: LDEvaluationDetail(LDValue.ofString('the-value'), 10,
            LDEvaluationReason.fallthrough()),
        withReason: true,
        trackEvent: false);

    final json = jsonEncode(EvalEventSerialization.toJson(event,
        isDebug: true,
        allAttributesPrivate: false,
        globalPrivateAttributes: {AttributeReference('/custom')}));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue = LDValueSerialization.fromJson(jsonDecode('{'
        '"kind": "debug",'
        '"key": "the-flag",'
        '"version": 42,'
        '"creationDate": 0,'
        '"default": "default-value",'
        '"variation": 10,'
        '"value": "the-value",'
        '"reason": {"kind": "FALLTHROUGH"},'
        '"context": {'
        '"kind": "user",'
        '"key": "user-key",'
        '"name":"the-name",'
        '"_meta": {"redactedAttributes":["/custom"]}'
        '}'
        '}'));

    expect(jsonAsLdValue, expectedLdValue);
  });

  test('can serialize summary event', () {
    final event = SummaryEvent(
        startDate: DateTime.fromMillisecondsSinceEpoch(0),
        endDate: DateTime.fromMillisecondsSinceEpoch(100),
        features: <String, FlagSummary>{
          'a': FlagSummary(
              defaultValue: LDValue.ofString('default-value'),
              counters: [
                FlagCounter(
                    value: LDValue.ofString('the-value'),
                    count: 10,
                    variation: 2,
                    version: 42)
              ],
              contextKinds: [
                'user',
                'org'
              ]),
          'b': FlagSummary(
              defaultValue: LDValue.ofString('default-value'),
              counters: [
                FlagCounter(
                    value: LDValue.ofString('another-value'),
                    count: 11,
                    unknown: true)
              ],
              contextKinds: [
                'potato',
                'org'
              ])
        });

    final json = jsonEncode(SummaryEventSerialization.toJson(event));

    final jsonAsLdValue = LDValueSerialization.fromJson(jsonDecode(json));

    final expectedLdValue =
        LDValueSerialization.fromJson(jsonDecode('{"kind":"summary",'
            '"startDate":0,'
            '"endDate":100,'
            '"features":{'
            '"a":{"default":"default-value",'
            '"contextKinds":["user","org"],'
            '"counters":[{"value":"the-value","count":10,"version":42,"variation":2}]},'
            '"b":{"default":"default-value",'
            '"contextKinds":["potato","org"],'
            '"counters":[{"value":"another-value","count":11,"unknown":true}]}}}'));

    expect(jsonAsLdValue, expectedLdValue);
  });
}
