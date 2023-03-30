import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

class BuildTester<TBuilder, TBuilt> {
  final TBuilder Function() constructor;
  final TBuilt Function(TBuilder) buildMethod;

  BuildTester(this.constructor, this.buildMethod);

  BuildPropertyTester<TBuilder, TBuilt, TValue> prop<TValue>(
    TValue Function(TBuilt) getter,
    void Function(TBuilder, TValue) setter) {
    return BuildPropertyTester(this, getter, setter);
  }
}

class BuildPropertyTester<TBuilder, TBuilt, TValue> {
  final BuildTester<TBuilder, TBuilt> owner;
  final TValue Function(TBuilt) getter;
  final void Function(TBuilder, TValue) builderSetter;

  BuildPropertyTester(this.owner, this.getter, this.builderSetter);

  expectDefault(TValue defaultValue) {
    TBuilder b = owner.constructor();
    expectValue(b, defaultValue);
  }

  expectCanSet(TValue newValue) {
    expectSetIsChangedTo(newValue, newValue);
  }

  expectSetIsChangedTo(TValue attemptedValue, TValue resultingValue) {
    TBuilder b = owner.constructor();
    builderSetter(b, attemptedValue);
    expectValue(b, resultingValue);
  }

  expectValue(TBuilder b, TValue v) {
    TBuilt o = owner.buildMethod(b);
    expect(getter(o), equals(v));
  }
}

void main() {
  var tester = BuildTester<LDConfigBuilder, LDConfig>(
    () { return LDConfigBuilder("test-key"); },
    (builder) { return builder.build(); });

  test('mobileKey', () {
    var builder = LDConfigBuilder("test-key");
    expect(builder.build().mobileKey, equals("test-key"));
  });

  test('applicationId', () {
    var propTester = tester.prop<String>((c) => c.applicationId, (b, v) => b.applicationId(v));
    propTester.expectDefault("");
    propTester.expectCanSet("myId");
  });

  test('applicationVersion', () {
    var propTester = tester.prop<String>((c) => c.applicationVersion, (b, v) => b.applicationVersion(v));
    propTester.expectDefault("");
    propTester.expectCanSet("myVersion");
  });

  test('pollUri', () {
    var propTester = tester.prop<String>((c) => c.pollUri, (b, v) => b.pollUri(v));
    propTester.expectDefault("https://clientsdk.launchdarkly.com");
    propTester.expectCanSet("https://127.0.0.1");
  });

  test('eventsUri', () {
    var propTester = tester.prop<String>((c) => c.eventsUri, (b, v) => b.eventsUri(v));
    propTester.expectDefault("https://events.launchdarkly.com");
    propTester.expectCanSet("https://127.0.0.1");
  });

  test('streamUri', () {
    var propTester = tester.prop<String>((c) => c.streamUri, (b, v) => b.streamUri(v));
    propTester.expectDefault("https://clientstream.launchdarkly.com");
    propTester.expectCanSet("https://127.0.0.1");
  });

  test('eventsCapacity', () {
    var propTester = tester.prop<int>((c) => c.eventsCapacity, (b, v) => b.eventsCapacity(v));
    propTester.expectDefault(100);
    propTester.expectCanSet(50);
  });

  test('eventsFlushIntervalMillis', () {
    var propTester = tester.prop<int>((c) => c.eventsFlushIntervalMillis, (b, v) => b.eventsFlushIntervalMillis(v));
    propTester.expectDefault(30 * 1000);
    propTester.expectCanSet(60 * 1000);
  });

  test('connectionTimeoutMillis', () {
    var propTester = tester.prop<int>((c) => c.connectionTimeoutMillis, (b, v) => b.connectionTimeoutMillis(v));
    propTester.expectDefault(10 * 1000);
    propTester.expectCanSet(30 * 1000);
  });

  test('pollingIntervalMillis', () {
    var propTester = tester.prop<int>((c) => c.pollingIntervalMillis, (b, v) => b.pollingIntervalMillis(v));
    propTester.expectDefault(5 * 60 * 1000);
    propTester.expectCanSet(10 * 60 * 1000);
  });

  test('backgroundPollingIntervalMillis', () {
    var propTester = tester.prop<int>((c) => c.backgroundPollingIntervalMillis, (b, v) => b.backgroundPollingIntervalMillis(v));
    propTester.expectDefault(60 * 60 * 1000);
    propTester.expectCanSet(2 * 60 * 60 * 1000);
  });

  test('diagnosticRecordingIntervalMillis', () {
    var propTester = tester.prop<int>((c) => c.diagnosticRecordingIntervalMillis, (b, v) => b.diagnosticRecordingIntervalMillis(v));
    propTester.expectDefault(15 * 60 * 1000);
    propTester.expectCanSet(30 * 60 * 1000);
  });

  test('maxCachedUsers', () {
    var propTester = tester.prop<int>((c) => c.maxCachedUsers, (b, v) => b.maxCachedUsers(v));
    propTester.expectDefault(5);
    propTester.expectCanSet(10);
    propTester.expectCanSet(-1);
    propTester.expectSetIsChangedTo(-2, -1);
  });

  test('stream', () {
    var propTester = tester.prop<bool>((c) => c.stream, (b, v) => b.stream(v));
    propTester.expectDefault(true);
    propTester.expectCanSet(false);
  });

  test('offline', () {
    var propTester = tester.prop<bool>((c) => c.offline, (b, v) => b.offline(v));
    propTester.expectDefault(false);
    propTester.expectCanSet(true);
  });

  test('disableBackgroundUpdating', () {
    var propTester = tester.prop<bool>((c) => c.disableBackgroundUpdating, (b, v) => b.disableBackgroundUpdating(v));
    propTester.expectDefault(true);
    propTester.expectCanSet(false);
  });

  test('useReport', () {
    var propTester = tester.prop<bool>((c) => c.useReport, (b, v) => b.useReport(v));
    propTester.expectDefault(false);
    propTester.expectCanSet(true);
  });

  test('inlineUsersInEvents', () {
    var propTester = tester.prop<bool>((c) => c.inlineUsersInEvents, (b, v) => b.inlineUsersInEvents(v));
    propTester.expectDefault(false);
    propTester.expectCanSet(true);
  });

  test('evaluationReasons', () {
    var propTester = tester.prop<bool>((c) => c.evaluationReasons, (b, v) => b.evaluationReasons(v));
    propTester.expectDefault(false);
    propTester.expectCanSet(true);
  });

  test('diagnosticOptOut', () {
    var propTester = tester.prop<bool>((c) => c.diagnosticOptOut, (b, v) => b.diagnosticOptOut(v));
    propTester.expectDefault(false);
    propTester.expectCanSet(true);
  });

  test('autoAliasingOptOut', () {
    var propTester = tester.prop<bool>((c) => c.autoAliasingOptOut, (b, v) => b.autoAliasingOptOut(v));
    propTester.expectDefault(false);
    propTester.expectCanSet(true);
  });

  test('allAttributesPrivate', () {
    var propTester = tester.prop<bool>((c) => c.allAttributesPrivate, (b, v) => b.allAttributesPrivate(v));
    propTester.expectDefault(false);
    propTester.expectCanSet(true);
  });

  test('privateAttributeNames', () {
    var propTester = tester.prop<dynamic>((c) => c.privateAttributeNames, (b, v) => b.privateAttributeNames(Set.castFrom(v)));
    propTester.expectDefault(null);
    propTester.expectSetIsChangedTo(Set(), null);
    propTester.expectSetIsChangedTo(Set.of(["phone"]), ["phone"]);
  });
}
