// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:launchdarkly_event_source_client/src/http_consts.dart';
import 'package:launchdarkly_event_source_client/src/message_event.dart';
import 'package:launchdarkly_event_source_client/src/sse_client_http.dart';
import 'package:launchdarkly_event_source_client/src/state_connected.dart';
import 'package:launchdarkly_event_source_client/src/state_connecting.dart';
import 'package:launchdarkly_event_source_client/src/state_idle.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'test_utils.dart';
import 'package:http/http.dart' as http;

class MockClient extends Mock implements BaseClient {}

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
        math.Random(),
        null,
        'GET');

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
        math.Random(),
        null,
        'GET');

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
        math.Random(),
        null,
        'GET');

    // this expect statement will register a listener on the stream triggering the client to
    // connect to the mock client.
    var messageEvent = await sseClientUnderTest.stream.first;
    expect(messageEvent.data, equals('helloworld'));
    sseClientUnderTest.close();
  });

  group('given different http methods', () {
    registerFallbackValue(
        http.Request('POTATO', Uri.parse('http://localhost:8080')));
    for (var method in ['GET', 'POST', 'REPORT']) {
      test('it supports setting HTTP method', () async {
        final transitionController = StreamController<dynamic>.broadcast();
        // Listen to trigger things happening.
        transitionController.stream.listen((event) {});

        final mockClient = MockClient();
        final sseClientUnderTest = HttpSseClient.internal(
            Uri.parse('/path'),
            {'put'},
            {},
            Duration(days: 99),
            Duration(days: 99),
            transitionController.sink, (
                {int httpStatusCode = HttpStatusCodes.okStatus,
                Map<String, String> headers = const {},
                bool blocking = false}) {
          return mockClient;
        }, math.Random(), null, method);

        when(() => mockClient.send(any())).thenAnswer((_) async {
          return http.StreamedResponse(
              ByteStream.fromBytes(
                  utf8.encode('event:put\ndata:helloworld\n\n')),
              200,
              headers: {'content-type': 'text/event-stream'});
        });

        // Start listening so the SSE client conntects.
        sseClientUnderTest.stream.listen((event) {});

        final res = await untilCalled(() => mockClient.send(any()));
        expect((res.positionalArguments[0] as http.Request).method, method);
      });
    }
  });

  test('Includes specified headers', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    // Listen to trigger things happening.
    transitionController.stream.listen((event) {});

    final mockClient = MockClient();
    final sseClientUnderTest = HttpSseClient.internal(
        Uri.parse('/path'),
        {'put'},
        {'test-header': 'test-value'},
        Duration(days: 99),
        Duration(days: 99),
        transitionController.sink, (
            {int httpStatusCode = HttpStatusCodes.okStatus,
            Map<String, String> headers = const {},
            bool blocking = false}) {
      return mockClient;
    }, math.Random(), null, 'GET');

    when(() => mockClient.send(any())).thenAnswer((_) async {
      return http.StreamedResponse(
          ByteStream.fromBytes(utf8.encode('event:put\ndata:helloworld\n\n')),
          200,
          headers: {'content-type': 'text/event-stream'});
    });

    // Start listening so the SSE client conntects.
    sseClientUnderTest.stream.listen((event) {});

    final res = await untilCalled(() => mockClient.send(any()));
    expect((res.positionalArguments[0] as http.Request).headers,
        {'test-header': 'test-value'});
  });
}
