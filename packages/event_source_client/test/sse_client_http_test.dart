import 'dart:async';
import 'dart:math' as math;

import 'package:launchdarkly_event_source_client/src/message_event.dart';
import 'package:launchdarkly_event_source_client/src/sse_client_http.dart';
import 'package:launchdarkly_event_source_client/src/state_connected.dart';
import 'package:launchdarkly_event_source_client/src/state_connecting.dart';
import 'package:launchdarkly_event_source_client/src/state_idle.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('Test connects when subscribed', () async {
    final transitionController = StreamController<dynamic>.broadcast();

    // set up this expect before client creation to detect the first idle state
    expectLater(transitionController.stream,
        emitsInOrder([StateIdle, StateConnecting, StateConnected]));

    final sseClientUnderTest = HttpSseClient.internal(
        Uri.parse('/path'),
        {'put'},
        {},
        Duration(days: 99),
        Duration(days: 99),
        transitionController.sink,
        TestUtils.makeMockHttpClient,
        math.Random());

    // this expect statement will register a listener on the stream triggering the client to
    // connect to the mock client.  The mock client is set up to send a message.
    expectLater(sseClientUnderTest.stream,
        emitsInOrder([MessageEvent('put', 'helloworld', '')]));
  });

  test('Test disconnects when stream.first unsubscribes', () async {
    final transitionController = StreamController<dynamic>.broadcast();

    // set up this expect before client creation to detect the first idle state
    expectLater(transitionController.stream,
        emitsInOrder([StateIdle, StateConnecting, StateConnected, StateIdle]));

    final sseClientUnderTest = HttpSseClient.internal(
        Uri.parse('/path'),
        {'put'},
        {},
        Duration(days: 99),
        Duration(days: 99),
        transitionController.sink,
        TestUtils.makeMockHttpClient,
        math.Random());

    // this expect statement will register a listener on the stream triggering the client to
    // connect to the mock client.  The mock client is set up to send a message.
    var messageEvent = await sseClientUnderTest.stream.first;
    expect(messageEvent.data, equals('helloworld'));
  });

  test('Test close', () async {
    final transitionController = StreamController<dynamic>.broadcast();

    // set up this expect before client creation to detect the first idle state
    expectLater(transitionController.stream,
        emitsInOrder([StateIdle, StateConnecting, StateConnected, StateIdle]));

    final sseClientUnderTest = HttpSseClient.internal(
        Uri.parse('/path'),
        {'put'},
        {},
        Duration(days: 99),
        Duration(days: 99),
        transitionController.sink,
        TestUtils.makeMockHttpClient,
        math.Random());

    // this expect statement will register a listener on the stream triggering the client to
    // connect to the mock client.
    var messageEvent = await sseClientUnderTest.stream.first;
    expect(messageEvent.data, equals('helloworld'));
    sseClientUnderTest.close();
  });
}
