import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

const MethodChannel channel = MethodChannel('launchdarkly_flutter_client_sdk');
const String _sdkVersion = "0.1.0";

void main() {
  group('LDValue', testLDValue);
  group('LDUser', testLDUser);
  group('LDConnectionInformation', testLDConnectionInformation);
  group('LDEvaluationDetail', testLDEvaluationDetail);
  group('LDClient', testLDClient);
}

void testLDValue() {
  test('normalize', () {
    LDValue valid = LDValue.ofString('abc');
    expect(LDValue.normalize(null), same(LDValue.ofNull()));
    expect(LDValue.normalize(LDValue.ofNull()), same(LDValue.ofNull()));
    expect(LDValue.normalize(valid), same(valid));
  });

  test('ofNull', () {
    LDValue ofNull = LDValue.ofNull();
    expect(ofNull.getType(), equals(LDValueType.NULL));
    expect(ofNull.codecValue(), isNull);
    expect(ofNull, same(LDValue.ofNull()));
    expect(ofNull == LDValue.ofNull(), isTrue);
  });

  test('ofBool', () {
    LDValue ofFalse = LDValue.ofBool(false);
    LDValue ofTrue = LDValue.ofBool(true);
    expect(ofFalse.getType(), equals(LDValueType.BOOLEAN));
    expect(ofTrue.getType(), equals(LDValueType.BOOLEAN));

    expect(ofFalse.booleanValue(), isFalse);
    expect(ofTrue.booleanValue(), isTrue);

    expect(ofFalse.codecValue(), equals(false));
    expect(ofTrue.codecValue(), equals(true));

    expect(ofFalse, same(LDValue.ofBool(false)));
    expect(ofTrue, same(LDValue.ofBool(true)));

    expect(ofFalse == LDValue.ofBool(false), isTrue);
    expect(ofFalse != LDValue.ofBool(true), isTrue);
    expect(ofTrue == LDValue.ofBool(true), isTrue);
    expect(ofTrue != LDValue.ofBool(false), isTrue);

    expect(LDValue.ofBool(null), same(LDValue.ofNull()));
  });

  test('ofNum', () {
    LDValue ofInt = LDValue.ofNum(5);
    LDValue ofDouble = LDValue.ofNum(8.75);
    expect(ofInt.getType(), equals(LDValueType.NUMBER));
    expect(ofDouble.getType(), equals(LDValueType.NUMBER));

    expect(ofInt.intValue(), 5);
    expect(ofDouble.intValue(), 8);
    expect(ofInt.doubleValue(), 5.0);
    expect(ofDouble.doubleValue(), 8.75);

    expect(ofInt.codecValue(), same(5));
    expect(ofDouble.codecValue(), same(8.75));

    expect(ofInt == LDValue.ofNum(5.0), isTrue);
    expect(ofDouble == LDValue.ofNum(8.75), isTrue);
    expect(ofInt != ofDouble, isTrue);

    expect(LDValue.ofNum(null), same(LDValue.ofNull()));
  });

  test('ofString', () {
    LDValue ofString = LDValue.ofString('abc');
    expect(ofString.getType(), equals(LDValueType.STRING));
    expect(ofString.stringValue(), equals('abc'));
    expect(ofString.codecValue(), equals('abc'));
    expect(ofString == LDValue.ofString('abc'), isTrue);
    expect(ofString != LDValue.ofString('def'), isTrue);
    expect(LDValue.ofString(null), same(LDValue.ofNull()));
  });

  group('Array', testLDValueArray);
  group('Object', testLDValueObject);
  group('fromCodecValue', testLDValueFromCodec);
}

void testLDValueArray() {
  test('size', () {
    expect(LDValue.buildArray().build().size(), equals(0));
    expect(LDValue.buildArray().addNum(3).build().size(), equals(1));
    expect(LDValue.buildArray().addNum(3).addNum(2).build().size(), equals(2));
  });

  test('getType', () {
    expect(LDValue.buildArray().build().getType(), equals(LDValueType.ARRAY));
    expect(LDValue.buildArray().addBool(true).build().getType(), equals(LDValueType.ARRAY));
  });

  test('get', () {
    LDValue testArray = LDValue.buildArray().addNum(1).addBool(false).build();
    expect(testArray.get(0), equals(LDValue.ofNum(1)));
    expect(testArray.get(1), equals(LDValue.ofBool(false)));
  });

  test('values', () {
    LDValue testArray = LDValue.buildArray().addString('abc').addValue(LDValue.ofNull()).build();
    List<LDValue> listOf = List.of(testArray.values());
    expect(listOf.length, 2);
    expect(listOf[0], equals(LDValue.ofString('abc')));
    expect(listOf[1], same(LDValue.ofNull()));
  });

  test('builder add', () {
    LDValue array = LDValue.buildArray()
        .addValue(LDValue.ofNull())
        .addBool(false)
        .addNum(1.0)
        .addString('abc')
        .addValue(LDValue.buildArray().build())
        .addValue(LDValue.buildObject().build())
        .build();
    expect(array.values(),
        containsAllInOrder(
            [LDValue.ofNull()
              , LDValue.ofBool(false)
              , LDValue.ofNum(1.0)
              , LDValue.ofString('abc')
              , LDValue.buildArray().build()
              , LDValue.buildObject().build()]));
    expect(array.values().length, 6);
  });

  test('builder normalize', () {
    LDValue normalizedArray = LDValue.buildArray().addBool(null).addNum(null).addString(null).addValue(null).build();
    expect(normalizedArray.values(), containsAllInOrder([LDValue.ofNull(), LDValue.ofNull(), LDValue.ofNull(), LDValue.ofNull()]));
    expect(normalizedArray.values().length, 4);
  });

  test('builder reuse', () {
    LDValueArrayBuilder builder = LDValue.buildArray().addNum(1);
    LDValue builtFirst = builder.build();
    builder.addNum(2);
    LDValue builtSecond = builder.build();
    expect(builtFirst, equals(LDValue.buildArray().addNum(1).build()));
    expect(builtSecond, equals(LDValue.buildArray().addNum(1).addNum(2).build()));
    expect(builtSecond, isNot(same(builder.build())));
  });
}

void testLDValueObject() {
  test('size', () {
    expect(LDValue.buildObject().build().size(), equals(0));
    expect(LDValue.buildObject().addNum('a', 3).build().size(), equals(1));
    expect(LDValue.buildObject().addNum('a', 3).addNum('b', 2).build().size(), equals(2));
  });

  test('getType', () {
    expect(LDValue.buildObject().build().getType(), equals(LDValueType.OBJECT));
    expect(LDValue.buildObject().addBool('k', true).build().getType(), equals(LDValueType.OBJECT));
  });

  test('getFor', () {
    LDValue testObject = LDValue.buildObject().addNum('k1', 1).addBool('k2', false).build();
    expect(testObject.getFor('k1'), equals(LDValue.ofNum(1)));
    expect(testObject.getFor('k2'), equals(LDValue.ofBool(false)));
  });

  test('keys', () {
    LDValue testObject = LDValue.buildObject().addString('a', 'def').addValue('b', LDValue.ofNull()).build();
    expect(testObject.keys(), containsAll(['a', 'b']));
    expect(testObject.keys().length, 2);
  });

  test('values', () {
    LDValue testObject = LDValue.buildObject().addString('c', 'abc').addValue('d', LDValue.ofNull()).build();
    expect(testObject.values(), containsAll([LDValue.ofString('abc'), LDValue.ofNull()]));
    expect(testObject.values().length, 2);
  });

  test('builder add', () {
    LDValue object = LDValue.buildObject()
        .addValue('a', LDValue.ofNull())
        .addBool('b', false)
        .addNum('c', 1.0)
        .addString('d', 'abc')
        .addValue('e', LDValue.buildArray().build())
        .addValue('f', LDValue.buildObject().build())
        .build();
    expect(object.getFor('a'), same(LDValue.ofNull()));
    expect(object.getFor('b'), same(LDValue.ofBool(false)));
    expect(object.getFor('c'), equals(LDValue.ofNum(1.0)));
    expect(object.getFor('d'), equals(LDValue.ofString('abc')));
    expect(object.getFor('e'), equals(LDValue.buildArray().build()));
    expect(object.getFor('f'), equals(LDValue.buildObject().build()));
    expect(object.size(), equals(6));
  });

  test('builder normalize', () {
    LDValue normalizedObject = LDValue.buildObject()
        .addBool('a', null)
        .addNum('b', null)
        .addString('c', null)
        .addValue('d', null)
        .build();
    expect(normalizedObject.values(), containsAll([LDValue.ofNull(), LDValue.ofNull(), LDValue.ofNull(), LDValue.ofNull()]));
    expect(normalizedObject.values().length, 4);
  });

  test('builder reuse', () {
    LDValueObjectBuilder builder = LDValue.buildObject().addNum('k1', 1);
    LDValue builtFirst = builder.build();
    builder.addNum('k2', 2);
    LDValue builtSecond = builder.build();
    expect(builtFirst, equals(LDValue.buildObject().addNum('k1', 1).build()));
    expect(builtSecond, equals(LDValue.buildObject().addNum('k1', 1).addNum('k2', 2).build()));
    expect(builtSecond, isNot(same(builder.build())));
  });
}

void testLDValueFromCodec() {
  test('primitives', () {
    expect(LDValue.fromCodecValue(null), same(LDValue.ofNull()));
    expect(LDValue.fromCodecValue(false), same(LDValue.ofBool(false)));
    expect(LDValue.fromCodecValue(true), same(LDValue.ofBool(true)));
    expect(LDValue.fromCodecValue(5), equals(LDValue.ofNum(5)));
    expect(LDValue.fromCodecValue(8.75), equals(LDValue.ofNum(8.75)));
    expect(LDValue.fromCodecValue('abcd'), equals(LDValue.ofString('abcd')));

    // Invalid primitive
    expect(LDValue.fromCodecValue(DateTime.now()), same(LDValue.ofNull()));
  });

  test('primitive arrays', () {
    expect(LDValue.fromCodecValue([]), equals(LDValue.buildArray().build()));
    expect(LDValue.fromCodecValue([null]), equals(LDValue.buildArray().addValue(LDValue.ofNull()).build()));
    expect(LDValue.fromCodecValue([false, true]), equals(LDValue.buildArray().addBool(false).addBool(true).build()));
    expect(LDValue.fromCodecValue([1, 2]), equals(LDValue.buildArray().addNum(1).addNum(2).build()));
    expect(LDValue.fromCodecValue(['abc', 'def']), equals(LDValue.buildArray().addString('abc').addString('def').build()));
    expect(LDValue.fromCodecValue([null, true, 3.0, 'c']),
        equals(LDValue.buildArray().addValue(LDValue.ofNull()).addBool(true).addNum(3.0).addString('c').build()));

    // Invalid primitive in array
    expect(LDValue.fromCodecValue([DateTime.now()]), equals(LDValue.buildArray().addValue(LDValue.ofNull()).build()));
  });

  test('deep array', () {
    LDValue expected = LDValue.buildArray()
        .addValue(LDValue.buildArray().addNum(1).addNum(2).build())
        .addValue(LDValue.buildObject().addString('k', 'v').build())
        .addValue(LDValue.buildArray().addValue(LDValue.buildArray().addValue(LDValue.ofNull()).build()).build())
        .build();
    expect(LDValue.fromCodecValue([[1, 2], {'k': 'v'}, [[null]]]), equals(expected));
  });

  test('primitive objects', () {
    expect(LDValue.fromCodecValue({}), equals(LDValue.buildObject().build()));
    expect(LDValue.fromCodecValue({'n': null}), equals(LDValue.buildObject().addValue('n', LDValue.ofNull()).build()));
    expect(LDValue.fromCodecValue({'true': true, 'false': false}),
        equals(LDValue.buildObject().addBool('true', true).addBool('false', false).build()));
    expect(LDValue.fromCodecValue({'a': 1, 'b': 2}),
        equals(LDValue.buildObject().addNum('a', 1).addNum('b', 2).build()));
    expect(LDValue.fromCodecValue({'': 'abc', 'def': 'bar'}),
      equals(LDValue.buildObject().addString('', 'abc').addString('def', 'bar').build()));

    // Invalid primitive in object
    expect(LDValue.fromCodecValue({'k': DateTime.now()}), equals(LDValue.buildObject().addValue('k', LDValue.ofNull()).build()));
  });

  test('deep object', () {
    LDValue expected = LDValue.buildObject()
        .addValue('a', LDValue.buildObject().build())
        .addValue('b', LDValue.buildArray().addBool(false).addValue(LDValue.ofNull()).build())
        .addValue('c', LDValue.buildObject().addString('k', 'abc').build())
        .build();
    expect(LDValue.fromCodecValue({'a': {}, 'b': [false, null], 'c': {'k': 'abc'}}), equals(expected));
  });
}

class LDUserAttr {
  static List<LDUserAttr> builtInAttrs =
    [ LDUserAttr('secondary', (b, v) { b.secondary(v); }, (b, v) { b.privateSecondary(v); }, (u) { return u.secondary; })
    , LDUserAttr('ip', (b, v) { b.ip(v); }, (b, v) { b.privateIp(v); }, (u) { return u.ip; })
    , LDUserAttr('email', (b, v) { b.email(v); }, (b, v) { b.privateEmail(v); }, (u) { return u.email; })
    , LDUserAttr('name', (b, v) { b.name(v); }, (b, v) { b.privateName(v); }, (u) { return u.name; })
    , LDUserAttr('firstName', (b, v) { b.firstName(v); }, (b, v) { b.privateFirstName(v); }, (u) { return u.firstName; })
    , LDUserAttr('lastName', (b, v) { b.lastName(v); }, (b, v) { b.privateLastName(v); }, (u) { return u.lastName; })
    , LDUserAttr('avatar', (b, v) { b.avatar(v); }, (b, v) { b.privateAvatar(v); }, (u) { return u.avatar; })
    , LDUserAttr('country', (b, v) { b.country(v); }, (b, v) { b.privateCountry(v); }, (u) { return u.country; })];

  final String fieldName;
  final void Function(LDUserBuilder, String) setPublic;
  final void Function(LDUserBuilder, String) setPrivate;
  final String Function(LDUser) getter;

  LDUserAttr(this.fieldName, this.setPublic, this.setPrivate, this.getter);
}

void testLDUser() {
  test('builder built-in attributes public', () {
    LDUser user = LDUserBuilder('user key')
        .anonymous(false)
        .secondary('abc')
        .ip('192.0.2.5')
        .email('test@example.com')
        .name('a b')
        .firstName('c')
        .lastName('d')
        .avatar('cat')
        .country('de')
        .build();
    expect(user.key, equals('user key'));
    expect(user.anonymous, isFalse);
    expect(user.secondary, equals('abc'));
    expect(user.ip, equals('192.0.2.5'));
    expect(user.email, equals('test@example.com'));
    expect(user.name, equals('a b'));
    expect(user.firstName, equals('c'));
    expect(user.lastName, equals('d'));
    expect(user.avatar, equals('cat'));
    expect(user.country, equals('de'));
    expect(user.custom, isNull);
    expect(user.privateAttributeNames, isNull);
  });

  test('builder private built-in attributes', () {
    LDUserAttr.builtInAttrs.forEach((attr) {
      LDUserBuilder builder = LDUserBuilder('user key');
      attr.setPrivate(builder, 'val');
      LDUser user = builder.build();
      expect(user.privateAttributeNames.length, equals(1));
      expect(user.privateAttributeNames[0], equals(attr.fieldName));
      expect(attr.getter(user), equals('val'));
    });
  });

  test('builder custom attrs', () {
    LDUser user = LDUserBuilder('user key')
        .custom('custom1', LDValue.ofNull())
        .custom('custom2', LDValue.ofBool(false))
        .privateCustom('custom3', LDValue.ofString('abc'))
        .build();
    expect(user.custom['custom1'], same(LDValue.ofNull()));
    expect(user.custom['custom2'], same(LDValue.ofBool(false)));
    expect(user.custom['custom3'], equals(LDValue.ofString('abc')));
    expect(user.privateAttributeNames.length, equals(1));
    expect(user.privateAttributeNames[0], equals('custom3'));
  });
}

void testLDConnectionInformation() {
  test('LDFailure constructor', () {
    LDFailure failure = LDFailure('description', LDFailureType.NETWORK_FAILURE);
    expect(failure.message, equals('description'));
    expect(failure.failureType, equals(LDFailureType.NETWORK_FAILURE));
  });

  test('LDConnectionInformation constructor', () {
    LDConnectionInformation connInfo = LDConnectionInformation(LDConnectionState.OFFLINE, null, null, null);
    expect(connInfo.connectionState, equals(LDConnectionState.OFFLINE));
    expect(connInfo.lastFailure, isNull);
    expect(connInfo.lastSuccessfulConnection, isNull);
    expect(connInfo.lastFailedConnection, isNull);
    LDFailure failure = LDFailure('failure', LDFailureType.UNEXPECTED_STREAM_ELEMENT_TYPE);
    connInfo = LDConnectionInformation(LDConnectionState.POLLING, failure, DateTime.utc(2020), DateTime.utc(2021));
    expect(connInfo.connectionState, equals(LDConnectionState.POLLING));
    expect(connInfo.lastFailure.message, 'failure');
    expect(connInfo.lastFailure.failureType, LDFailureType.UNEXPECTED_STREAM_ELEMENT_TYPE);
    expect(connInfo.lastSuccessfulConnection, DateTime.utc(2020));
    expect(connInfo.lastFailedConnection, DateTime.utc(2021));
  });
}

void testLDEvaluationDetail() {
  test('.off()', () {
    LDEvaluationReason reason = LDEvaluationReason.off();
    expect(reason.kind, equals(LDKind.OFF));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason, same(LDEvaluationReason.off()));
  });

  test('.fallthrough()', () {
    LDEvaluationReason reason = LDEvaluationReason.fallthrough();
    expect(reason.kind, equals(LDKind.FALLTHROUGH));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason, same(LDEvaluationReason.fallthrough()));
  });

  test('.targetMatch()', () {
    LDEvaluationReason reason = LDEvaluationReason.targetMatch();
    expect(reason.kind, equals(LDKind.TARGET_MATCH));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason, same(LDEvaluationReason.targetMatch()));
  });

  test('.ruleMatch()', () {
    LDEvaluationReason reason = LDEvaluationReason.ruleMatch(ruleIndex: 1, ruleId: 'abc');
    expect(reason.kind, equals(LDKind.RULE_MATCH));
    expect(reason.ruleIndex, equals(1));
    expect(reason.ruleId, equals('abc'));
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
  });

  test('.prerequisiteFailed()', () {
    LDEvaluationReason reason = LDEvaluationReason.prerequisiteFailed(prerequisiteKey: 'def');
    expect(reason.kind, equals(LDKind.PREREQUISITE_FAILED));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, equals('def'));
    expect(reason.errorKind, isNull);
  });

  test('.error()', () {
    LDEvaluationReason reason = LDEvaluationReason.error(errorKind: LDErrorKind.FLAG_NOT_FOUND);
    expect(reason.kind, equals(LDKind.ERROR));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, LDErrorKind.FLAG_NOT_FOUND);
  });

  test('.unknown()', () {
    LDEvaluationReason reason = LDEvaluationReason.unknown();
    expect(reason.kind, equals(LDKind.UNKNOWN));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason, same(LDEvaluationReason.unknown()));
  });

  test('LDEvaluationDetail constructor', () {
    LDEvaluationDetail detail = LDEvaluationDetail('abc', 3, LDEvaluationReason.off());
    expect(detail.value, equals('abc'));
    expect(detail.variationIndex, equals(3));
    expect(detail.reason, same(LDEvaluationReason.off()));
  });
}

Map<String, dynamic> emptyConfig() {
  final Map<String, dynamic> result = <String, dynamic>{};
  ['mobileKey', 'baseUri', 'eventsUri', 'streamUri', 'eventsCapacity', 'eventsFlushIntervalMillis'
    , 'connectionTimeoutMillis', 'pollingIntervalMillis', 'backgroundPollingIntervalMillis'
    , 'diagnosticRecordingIntervalMillis', 'allAttributesPrivate', 'privateAttributeNames'].forEach((configName) {
    result[configName] = null;
  });
  result['stream'] = true;
  result['offline'] = false;
  result['disableBackgroundUpdating'] = true;
  result['useReport'] = false;
  result['inlineUsersInEvents'] = false;
  result['evaluationReasons'] = false;
  result['diagnosticOptOut'] = false;
  result['wrapperName'] = 'FlutterClientSdk';
  result['wrapperVersion'] = _sdkVersion;
  return result;
}

Map<String, dynamic> emptyUser() {
  final Map<String, dynamic> result = <String, dynamic>{};
  ['key', 'anonymous', 'secondary', 'ip', 'email', 'name', 'firstName', 'lastName', 'avatar', 'country', 'custom'
    , 'privateAttributeNames'].forEach((attrName) {
    result[attrName] = null;
  });
  return result;
}

List<LDValue> ldValueTestValues =
  [ LDValue.ofNull()
  , LDValue.ofBool(false)
  , LDValue.ofNum(2)
  , LDValue.ofNum(1.25)
  , LDValue.ofString('abc')
  , LDValue.fromCodecValue([[1, 2], {'k': 'v'}, [[null]]])
  , LDValue.fromCodecValue({'a': {}, 'b': [false, null], 'c': {'k': 'abc'}})];

List<MethodCall> callQueue = [];
dynamic callReturn = null;
MethodCall get takeCall => callQueue.removeAt(0);

void expectCall(String name, dynamic arguments) => expect(takeCall, isMethodCall(name, arguments: arguments));

Future<dynamic> mockHandler(MethodCall methodCall) async {
  callQueue.add(methodCall);
  return callReturn;
}

void testLDClient() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler(mockHandler);
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
    expect(callQueue.isEmpty, isTrue);
    callQueue.clear();
    callReturn = null;
  });

  test('start', () async {
    LDConfig config = LDConfigBuilder('mobile key').build();
    LDUser user = LDUserBuilder('user key').build();
    Map<String, dynamic> expectedConfig = emptyConfig();
    expectedConfig['mobileKey'] = 'mobile key';
    Map<String, dynamic> expectedUser = emptyUser();
    expectedUser['key'] = 'user key';
    await LDClient.start(config, user);
    expectCall('start', {'config': expectedConfig, 'user': expectedUser });
  });

  test('identify', () async {
    LDUser user = LDUserBuilder('user key')
        .email('test@example.com')
        .privateIp('192.0.2.5')
        .custom('data', LDValue.buildObject().addBool('isValid', true).build())
        .build();
    Map<String, dynamic> expectedUser = emptyUser();
    expectedUser['key'] = 'user key';
    expectedUser['email'] = 'test@example.com';
    expectedUser['ip'] = '192.0.2.5';
    expectedUser['custom'] = { 'data': { 'isValid': true } };
    expectedUser['privateAttributeNames'] = ['ip'];
    await LDClient.identify(user);
    expectCall('identify', {'user': expectedUser });
  });

  test('track', () async {
    await LDClient.track('testEvent');
    await LDClient.track('testEvent', data: LDValue.buildArray().addNum(1).addNum(2).build());
    await LDClient.track('testEvent', metricValue: 4);
    await LDClient.track('testEvent', data: LDValue.ofString('abc'), metricValue: 1.25);
    expectCall('track', {'eventName': 'testEvent', 'data': null, 'metricValue': null});
    expectCall('track', {'eventName': 'testEvent', 'data': [1, 2], 'metricValue': null});
    expectCall('track', {'eventName': 'testEvent', 'data': null, 'metricValue': 4.0});
    expectCall('track', {'eventName': 'testEvent', 'data': 'abc', 'metricValue': 1.25});
  });

  test('boolVariation', () async {
    await Future.forEach([false, true], (val) async {
      callReturn = val;
      expect(await LDClient.boolVariation('flagKey', !val), equals(val));
      expectCall('boolVariation', {'flagKey': 'flagKey', 'defaultValue': !val});
    });
  });

  test('boolVariationDetail', () async {
    callReturn = {'value': true, 'variationIndex': 2, 'reason': { 'kind': 'OFF' }};
    LDEvaluationDetail<bool> result = await LDClient.boolVariationDetail('flagKey', false);
    expectCall('boolVariationDetail', {'flagKey': 'flagKey', 'defaultValue': false});
    expect(result.value, equals(true));
    expect(result.variationIndex, equals(2));
    expect(result.reason, same(LDEvaluationReason.off()));

    callReturn = {'value': true, 'variationIndex': 2, 'reason': { 'kind': 'UNKNOWN' }};
    result = await LDClient.boolVariationDetail('flagKey', false);
    expectCall('boolVariationDetail', {'flagKey': 'flagKey', 'defaultValue': false});
    expect(result.value, equals(true));
    expect(result.variationIndex, equals(2));
    expect(result.reason, same(LDEvaluationReason.unknown()));
  });

  test('intVariation', () async {
    callReturn = 3;
    expect(await LDClient.intVariation('flagKey', -1), equals(3));
    expectCall('intVariation', {'flagKey': 'flagKey', 'defaultValue': -1});
  });

  test('intVariationDetail', () async {
      callReturn = {'value': 4, 'variationIndex': null, 'reason': { 'kind': 'FALLTHROUGH' }};
      LDEvaluationDetail<int> result = await LDClient.intVariationDetail('flagKey', 2);
      expectCall('intVariationDetail', {'flagKey': 'flagKey', 'defaultValue': 2});
      expect(result.value, equals(4));
      expect(result.variationIndex, isNull);
      expect(result.reason, same(LDEvaluationReason.fallthrough()));

      callReturn = {'value': 4, 'variationIndex': null, 'reason': { 'kind': 'INVALID_KIND' }};
      result = await LDClient.intVariationDetail('flagKey', 2);
      expectCall('intVariationDetail', {'flagKey': 'flagKey', 'defaultValue': 2});
      expect(result.value, equals(4));
      expect(result.variationIndex, isNull);
      expect(result.reason, same(LDEvaluationReason.unknown()));
  });

  test('doubleVariation', () async {
    callReturn = -7.0;
    expect(await LDClient.doubleVariation('flagKey', 4.0), equals(-7.0));
    expectCall('doubleVariation', {'flagKey': 'flagKey', 'defaultValue': 4.0});
  });

  test('doubleVariationDetail', () async {
    callReturn = {'value': 1.25, 'variationIndex': 1, 'reason': { 'kind': 'TARGET_MATCH' }};
    LDEvaluationDetail<double> result = await LDClient.doubleVariationDetail('flagKey', 2.5);
    expectCall('doubleVariationDetail', {'flagKey': 'flagKey', 'defaultValue': 2.5});
    expect(result.value, equals(1.25));
    expect(result.variationIndex, equals(1));
    expect(result.reason, same(LDEvaluationReason.targetMatch()));

    callReturn = {'value': 1.25, 'variationIndex': 1, 'reason': { 'kind': 'PREREQUISITE_FAILED', 'prerequisiteKey': 'pid' }};
    result = await LDClient.doubleVariationDetail('flagKey', 2.5);
    expectCall('doubleVariationDetail', {'flagKey': 'flagKey', 'defaultValue': 2.5});
    expect(result.value, equals(1.25));
    expect(result.variationIndex, equals(1));
    expect(result.reason.kind, LDKind.PREREQUISITE_FAILED);
    expect(result.reason.prerequisiteKey, 'pid');
  });

  test('stringVariation', () async {
    callReturn = 'res';
    expect(await LDClient.stringVariation('flagKey', 'def'), equals('res'));
    expectCall('stringVariation', {'flagKey': 'flagKey', 'defaultValue': 'def'});
  });

  test('stringVariationDetail', () async {
    callReturn = {'value': 'abc', 'variationIndex': 1, 'reason': { 'kind': 'RULE_MATCH', 'ruleIndex': 1, 'ruleId': 'rid' }};
    LDEvaluationDetail<String> result = await LDClient.stringVariationDetail('flagKey', 'def');
    expectCall('stringVariationDetail', {'flagKey': 'flagKey', 'defaultValue': 'def'});
    expect(result.value, equals('abc'));
    expect(result.variationIndex, equals(1));
    expect(result.reason.kind, equals(LDKind.RULE_MATCH));
    expect(result.reason.ruleIndex, equals(1));
    expect(result.reason.ruleId, equals('rid'));

    callReturn = {'value': 'abc', 'variationIndex': 1, 'reason': { 'kind': 'ERROR', 'errorKind': 'INVALID_KIND' }};
    result = await LDClient.stringVariationDetail('flagKey', 'def');
    expectCall('stringVariationDetail', {'flagKey': 'flagKey', 'defaultValue': 'def'});
    expect(result.value, equals('abc'));
    expect(result.variationIndex, equals(1));
    expect(result.reason.kind, equals(LDKind.ERROR));
    expect(result.reason.errorKind, equals(LDErrorKind.UNKNOWN));
  });

  test('jsonVariation', () async {
    await Future.forEach(ldValueTestValues, (val) async {
      callReturn = val.codecValue();
      expect(await LDClient.jsonVariation('flagKey', LDValue.ofBool(true)), equals(val));
      expectCall('jsonVariation', {'flagKey': 'flagKey', 'defaultValue': true });
    });
  });

  test('jsonVariationDetail', () async {
    var errorKinds = LDErrorKind.values;
    List<String> errorKindStrings = ['CLIENT_NOT_READY', 'FLAG_NOT_FOUND', 'MALFORMED_FLAG', 'USER_NOT_SPECIFIED'
      , 'WRONG_TYPE', 'EXCEPTION', 'UNKNOWN'];

    for (int i = 0; i <7; i++) {
      callReturn = { 'value': ldValueTestValues[i].codecValue()
                   , 'variationIndex': 1
                   , 'reason': { 'kind': 'ERROR', 'errorKind': errorKindStrings[i] }};
      LDEvaluationDetail<LDValue> result = await LDClient.jsonVariationDetail('flagKey', LDValue.ofNum(17));
      expectCall('jsonVariationDetail', {'flagKey': 'flagKey', 'defaultValue': 17});
      expect(result.value, equals(ldValueTestValues[i]));
      expect(result.variationIndex, equals(1));
      expect(result.reason.kind, equals(LDKind.ERROR));
      expect(result.reason.errorKind, equals(errorKinds[i]));
    }
  });

  test('allFlags', () async {
    Map<String, dynamic> callRet = {};
    List<String> flagKeys = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
    for (int i = 0; i < 7; i++) {
      callRet[flagKeys[i]] = ldValueTestValues[i].codecValue();
    }
    callReturn = callRet;
    Map<String, LDValue> result = await LDClient.allFlags();
    expectCall('allFlags', null);
    expect(result.length, equals(7));
    for (int i = 0; i < 7; i++) {
      expect(result[flagKeys[i]], equals(ldValueTestValues[i]));
    }
  });

  test('flush', () async {
    await LDClient.flush();
    expectCall('flush', null);
  });

  test('setOnline', () async {
    Future.forEach([false, true], (val) async {
      await LDClient.setOnline(val);
      expectCall('setOnline', {'online': val});
    });
  });

  test('isOnline', () async {
    Future.forEach([false, true], (val) async {
      callReturn = val;
      expect(await LDClient.isOnline(), val);
      expectCall('isOnline', null);
    });
  });

  test('getConnectionInformation', () async {
    callReturn = { 'connectionState': 'STREAMING'
                 , 'lastFailure': { 'message': 'failure', 'failureType': 'NETWORK_FAILURE' }
                 , 'lastSuccessfulConnection': DateTime.utc(2020).millisecondsSinceEpoch
                 , 'lastFailedConnection': DateTime.utc(2021).millisecondsSinceEpoch };
    LDConnectionInformation connInfo = await LDClient.getConnectionInformation();
    expectCall('getConnectionInformation', null);
    expect(connInfo.connectionState, equals(LDConnectionState.STREAMING));
    expect(connInfo.lastSuccessfulConnection, equals(DateTime.utc(2020)));
    expect(connInfo.lastFailedConnection, equals(DateTime.utc(2021)));
    expect(connInfo.lastFailure.message, equals('failure'));
    expect(connInfo.lastFailure.failureType, equals(LDFailureType.NETWORK_FAILURE));
  });

  test('close', () async {
    await LDClient.close();
    expectCall('close', null);
  });

  test('featureFlagListener', () async {
    // Must start SDK before listeners can become active
    await LDClient.start(LDConfigBuilder('mobile key').build(), LDUserBuilder('user key').build());
    callQueue.removeAt(0);

    LDFlagUpdatedCallback callback = (flagKey) {
      expect(flagKey, equals('new_ui'));
    };
    var wrappedCallback = expectAsync1(callback);

    await LDClient.registerFeatureFlagListener('new_ui', wrappedCallback);
    expectCall('startFlagListening', 'new_ui');

    MethodCall call = MethodCall('handleFlagUpdate', 'new_ui');
    ByteData message = StandardMethodCodec().encodeMethodCall(call);
    BinaryMessenger messenger = ServicesBinding.instance.defaultBinaryMessenger;
    messenger.handlePlatformMessage('launchdarkly_flutter_client_sdk', message, null);

    await LDClient.unregisterFeatureFlagListener('new_ui', wrappedCallback);
    expectCall('stopFlagListening', 'new_ui');
  });

  test('flagsReceivedListener', () async {
    // Must start SDK before listeners can become active
    await LDClient.start(LDConfigBuilder('mobile key').build(), LDUserBuilder('user key').build());
    callQueue.removeAt(0);

    LDFlagsReceivedCallback callback = (flagKeys) {
      expect(flagKeys.length, equals(2));
      expect(flagKeys, containsAllInOrder(['abc', 'def']));
    };
    var wrappedCallback = expectAsync1(callback);

    await LDClient.registerFlagsReceivedListener(wrappedCallback);
    expect(callQueue.isEmpty, isTrue);

    MethodCall call = MethodCall('handleFlagsReceived', ['abc', 'def']);
    ByteData message = StandardMethodCodec().encodeMethodCall(call);
    BinaryMessenger messenger = ServicesBinding.instance.defaultBinaryMessenger;
    messenger.handlePlatformMessage('launchdarkly_flutter_client_sdk', message, null);

    await LDClient.unregisterFlagsReceivedListener(wrappedCallback);
    expect(callQueue.isEmpty, isTrue);
  });
}

