import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

const MethodChannel channel = MethodChannel('launchdarkly_flutter_client_sdk');
const String _sdkVersion = '3.0.0';

void main() {
  group('LDConnectionInformation', testLDConnectionInformation);
  group('LDEvaluationDetail', testLDEvaluationDetail);
  group('LDClient', testLDClient);
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
    expect(connInfo.lastFailure?.message, 'failure');
    expect(connInfo.lastFailure?.failureType, LDFailureType.UNEXPECTED_STREAM_ELEMENT_TYPE);
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
    expect(reason.inExperiment, isNull);
    expect(reason, same(LDEvaluationReason.off()));
  });

  test('.fallthrough()', () {
    LDEvaluationReason reason = LDEvaluationReason.fallthrough();
    expect(reason.kind, equals(LDKind.FALLTHROUGH));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason.inExperiment, equals(false));
    expect(reason, same(LDEvaluationReason.fallthrough()));
  });

  test('.fallthrough(inExperiment:false)', () {
    LDEvaluationReason reason = LDEvaluationReason.fallthrough(inExperiment: false);
    expect(reason.kind, equals(LDKind.FALLTHROUGH));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason.inExperiment, equals(false));
    expect(reason, same(LDEvaluationReason.fallthrough()));
    expect(reason, same(LDEvaluationReason.fallthrough(inExperiment: false)));
  });

  test('.fallthrough(inExperiment:true)', () {
    LDEvaluationReason reason = LDEvaluationReason.fallthrough(inExperiment: true);
    expect(reason.kind, equals(LDKind.FALLTHROUGH));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason.inExperiment, equals(true));
    expect(reason, same(LDEvaluationReason.fallthrough(inExperiment: true)));
  });

  test('.targetMatch()', () {
    LDEvaluationReason reason = LDEvaluationReason.targetMatch();
    expect(reason.kind, equals(LDKind.TARGET_MATCH));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason.inExperiment, isNull);
    expect(reason, same(LDEvaluationReason.targetMatch()));
  });

  test('.ruleMatch()', () {
    LDEvaluationReason reason = LDEvaluationReason.ruleMatch(ruleIndex: 1, ruleId: 'abc');
    expect(reason.kind, equals(LDKind.RULE_MATCH));
    expect(reason.ruleIndex, equals(1));
    expect(reason.ruleId, equals('abc'));
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason.inExperiment, equals(false));
  });
  test('.ruleMatch(inExperiment: true)', () {
    LDEvaluationReason reason = LDEvaluationReason.ruleMatch(ruleIndex: 1, ruleId: 'abc', inExperiment: true);
    expect(reason.kind, equals(LDKind.RULE_MATCH));
    expect(reason.ruleIndex, equals(1));
    expect(reason.ruleId, equals('abc'));
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason.inExperiment, equals(true));
  });

    test('.ruleMatch(inExperiment: false)', () {
    LDEvaluationReason reason = LDEvaluationReason.ruleMatch(ruleIndex: 1, ruleId: 'abc', inExperiment: false);
    expect(reason.kind, equals(LDKind.RULE_MATCH));
    expect(reason.ruleIndex, equals(1));
    expect(reason.ruleId, equals('abc'));
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason.inExperiment, equals(false));
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
    expect(reason.inExperiment, isNull);
    expect(reason.errorKind, LDErrorKind.FLAG_NOT_FOUND);
  });

  test('.unknown()', () {
    LDEvaluationReason reason = LDEvaluationReason.unknown();
    expect(reason.kind, equals(LDKind.UNKNOWN));
    expect(reason.ruleIndex, isNull);
    expect(reason.ruleId, isNull);
    expect(reason.prerequisiteKey, isNull);
    expect(reason.errorKind, isNull);
    expect(reason.inExperiment, isNull);
    expect(reason, same(LDEvaluationReason.unknown()));
  });

  test('LDEvaluationDetail constructor', () {
    LDEvaluationDetail detail = LDEvaluationDetail('abc', 3, LDEvaluationReason.off());
    expect(detail.value, equals('abc'));
    expect(detail.variationIndex, equals(3));
    expect(detail.reason, same(LDEvaluationReason.off()));
  });
}

Map<String, dynamic> defaultConfigBridged(String mobileKey) {
  final Map<String, dynamic> result = <String, dynamic>{};
  result['mobileKey'] = mobileKey;
  result['applicationId'] = null;
  result['applicationName'] = null;
  result['applicationVersion'] = null;
  result['applicationVersionName'] = null;
  result['pollUri'] = 'https://clientsdk.launchdarkly.com';
  result['streamUri'] = 'https://clientstream.launchdarkly.com';
  result['eventsUri'] = 'https://events.launchdarkly.com';
  result['eventsCapacity'] = 100;
  result['eventsFlushIntervalMillis'] = 30 * 1000;
  result['connectionTimeoutMillis'] = 10 * 1000;
  result['pollingIntervalMillis'] = 5 * 60 * 1000;
  result['backgroundPollingIntervalMillis'] = 60 * 60 * 1000;
  result['diagnosticRecordingIntervalMillis'] = 15 * 60 * 1000;
  result['maxCachedContexts'] = 5;
  result['stream'] = true;
  result['offline'] = false;
  result['disableBackgroundUpdating'] = true;
  result['useReport'] = false;
  result['evaluationReasons'] = false;
  result['diagnosticOptOut'] = false;
  result['autoEnvAttributes'] = true;
  result['allAttributesPrivate'] = false;
  result['privateAttributes'] = null;
  result['wrapperName'] = 'FlutterClientSdk';
  result['wrapperVersion'] = _sdkVersion;
  return result;
}

Map<String, dynamic> defaultUser(String userKey) {
  final Map<String, dynamic> result = <String, dynamic>{};
  result['key'] = userKey;
  result['anonymous'] = false;
  ['ip', 'email', 'name', 'firstName', 'lastName', 'avatar', 'country', 'custom'
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
dynamic callReturn;
MethodCall get takeCall => callQueue.removeAt(0);

void expectCall(String name, dynamic arguments) => expect(takeCall, isMethodCall(name, arguments: arguments));

Future<dynamic> mockHandler(MethodCall methodCall) async {
  callQueue.add(methodCall);
  return callReturn;
}

Future<void> simulateNativeCall(String method, dynamic arguments) async {
  MethodCall call = MethodCall(method, arguments);
  ByteData message = StandardMethodCodec().encodeMethodCall(call);
  BinaryMessenger messenger = ServicesBinding.instance!.defaultBinaryMessenger;
  await messenger.handlePlatformMessage('launchdarkly_flutter_client_sdk', message, null);
}

Future<void> expectCompleted(Future<dynamic> future) async {
  // Expected to immediately complete, so a zero duration timeout will throw a TimeoutException if not complete.
  await LDClient.startFuture().timeout(Duration());
}

Future<void> expectNotCompleted(Future<dynamic> future) async {
  try {
    await future.timeout(Duration(milliseconds: 50));
    fail('Expected future to time out');
  } on TimeoutException catch (_) { }
}

void testLDClient() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    channel.setMockMethodCallHandler(mockHandler);
    // Must start SDK so it can register it's native call handler before we can mock native calling into flutter
    LDContext context = (LDContextBuilder()..kind('user','user key')).build();
    await LDClient.start(LDConfigBuilder('mobile key', AutoEnvAttributes.Enabled).build(), context);
    callQueue.removeAt(0);
    // Force reset start completion to allow testing start completion behavior
    simulateNativeCall('_resetStartCompletion', null);
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
    expect(callQueue.isEmpty, isTrue);
    callQueue.clear();
    callReturn = null;
  });

  test('start', () async {
    LDConfig config = LDConfigBuilder('mobile key', AutoEnvAttributes.Enabled).build();
    LDContextBuilder builder = LDContextBuilder();
    builder.kind("kindA", "keyA").name("nameA");
    LDContext context = builder.build();
    Map<String, dynamic> expectedConfig = defaultConfigBridged('mobile key');
    Map<String, dynamic> expectedContext = {'kind':'kindA','key':'keyA', 'name':'nameA', '_meta':{}};
    await LDClient.start(config, context);
    expectCall('start', {'config': expectedConfig, 'context': [expectedContext] });
  });

  test('start with application info', () async {
    LDConfig config = LDConfigBuilder('mobile key', AutoEnvAttributes.Enabled)
        .applicationId('myId')
        .applicationName('myName')
        .applicationVersion('myVersion')
        .applicationVersionName('myVersionName')
        .build();
    LDContext context = (LDContextBuilder()..kind('user','user key')).build();
    Map<String, dynamic> expectedConfig = defaultConfigBridged('mobile key');
    Map<String, dynamic> expectedUser = defaultUser('user key');
    await LDClient.start(config, context);
    var arguments = takeCall.arguments['config'];
    expect(arguments['applicationId'], equals('myId'));
    expect(arguments['applicationName'], equals('myName'));
    expect(arguments['applicationVersion'], equals('myVersion'));
    expect(arguments['applicationVersionName'], equals('myVersionName'));
  });

  test('startFuture after completed', () async {
    await simulateNativeCall('completeStart', null);
    await expectCompleted(LDClient.startFuture());
  });

  test('startFutureTimeLimit after completed', () async {
    await simulateNativeCall('completeStart', null);
    await expectCompleted(LDClient.startFuture(timeLimit: Duration()));
  });

  test('startFuture before completed', () async {
    var startFuture = LDClient.startFuture();
    await expectNotCompleted(startFuture);
    await simulateNativeCall('completeStart', null);
    await expectCompleted(startFuture);
  });

  test('startFutureTimeLimit before completed', () async {
    var startFuture = LDClient.startFuture(timeLimit: Duration(milliseconds: 250));
    await expectNotCompleted(startFuture);
    await simulateNativeCall('completeStart', null);
    await expectCompleted(startFuture);
  });

  test('startFutureTimeLimit timeout', () async {
    var startFuture = LDClient.startFuture(timeLimit: Duration(milliseconds: 150));
    // Does not immediately complete
    await expectNotCompleted(startFuture);
    // but the startFuture timeLimit should complete before timeout
    expect(await startFuture.timeout(Duration(milliseconds: 150)).then((_) => true), equals(true));
    await simulateNativeCall('completeStart', null);
    // Calling again will give a new future with it's own timeout
    await expectCompleted(LDClient.startFuture(timeLimit: Duration(milliseconds: 150)));
  });

  test('isInitialized', () async {
    expect(LDClient.isInitialized(), equals(false));
    await simulateNativeCall('completeStart', null);
    expect(LDClient.isInitialized(), equals(true));
  });

  test('identify', () async {
    LDContextBuilder builder = LDContextBuilder();
    builder.kind("kindA", "keyA").name("nameA");
    LDContext context = builder.build();
    Map<String, dynamic> expectedContext = {'kind':'kindA','key':'keyA', 'name':'nameA', '_meta':{}};
    await LDClient.identify(context);
    expectCall('identify', {'context': [expectedContext] });
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
    await Future.forEach([false, true], (bool val) async {
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
      expect(result.variationIndex, equals(-1));
      expect(result.reason, same(LDEvaluationReason.fallthrough()));

      callReturn = {'value': 4, 'variationIndex': null, 'reason': { 'kind': 'INVALID_KIND' }};
      result = await LDClient.intVariationDetail('flagKey', 2);
      expectCall('intVariationDetail', {'flagKey': 'flagKey', 'defaultValue': 2});
      expect(result.value, equals(4));
      expect(result.variationIndex, equals(-1));
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
    LDEvaluationDetail<String?> result = await LDClient.stringVariationDetail('flagKey', 'def');
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
    await Future.forEach(ldValueTestValues, (LDValue val) async {
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
    Future.forEach([false, true], (bool val) async {
      await LDClient.setOnline(val);
      expectCall('setOnline', {'online': val});
    });
  });

  test('isOffline', () async {
    Future.forEach([false, true], (val) async {
      callReturn = val;
      expect(await LDClient.isOffline(), val);
      expectCall('isOffline', null);
    });
  });

  test('getConnectionInformation', () async {
    callReturn = { 'connectionState': 'STREAMING'
                 , 'lastFailure': { 'message': 'failure', 'failureType': 'NETWORK_FAILURE' }
                 , 'lastSuccessfulConnection': DateTime.utc(2020).millisecondsSinceEpoch
                 , 'lastFailedConnection': DateTime.utc(2021).millisecondsSinceEpoch };
    LDConnectionInformation? connInfo = await LDClient.getConnectionInformation();
    expectCall('getConnectionInformation', null);
    expect(connInfo?.connectionState, equals(LDConnectionState.STREAMING));
    expect(connInfo?.lastSuccessfulConnection, equals(DateTime.utc(2020)));
    expect(connInfo?.lastFailedConnection, equals(DateTime.utc(2021)));
    expect(connInfo?.lastFailure?.message, equals('failure'));
    expect(connInfo?.lastFailure?.failureType, equals(LDFailureType.NETWORK_FAILURE));
  });

  test('close', () async {
    await LDClient.close();
    expectCall('close', null);
  });

  test('featureFlagListener', () async {
    LDFlagUpdatedCallback callback = (flagKey) {
      expect(flagKey, equals('new_ui'));
    };
    var wrappedCallback = expectAsync1(callback);

    await LDClient.registerFeatureFlagListener('new_ui', wrappedCallback);
    expectCall('startFlagListening', 'new_ui');

    await simulateNativeCall('handleFlagUpdate', 'new_ui');

    await LDClient.unregisterFeatureFlagListener('new_ui', wrappedCallback);
    expectCall('stopFlagListening', 'new_ui');
  });

  test('flagsReceivedListener', () async {
    LDFlagsReceivedCallback callback = (flagKeys) {
      expect(flagKeys.length, equals(2));
      expect(flagKeys, containsAllInOrder(['abc', 'def']));
    };
    var wrappedCallback = expectAsync1(callback);

    await LDClient.registerFlagsReceivedListener(wrappedCallback);
    expect(callQueue.isEmpty, isTrue);

    await simulateNativeCall('handleFlagsReceived', ['abc', 'def']);

    await LDClient.unregisterFlagsReceivedListener(wrappedCallback);
    expect(callQueue.isEmpty, isTrue);
  });
}

