// ignore_for_file: close_sinks

import 'dart:async';

import 'package:http/http.dart'
    show BaseClient, BaseRequest, Client, ClientException, StreamedResponse;
import 'package:http/testing.dart' show MockClient;
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart'
    show Event, SseConnectionError, SseHttpError;
import 'package:launchdarkly_event_source_client/src/state_backoff.dart';
import 'package:launchdarkly_event_source_client/src/state_connected.dart';
import 'package:launchdarkly_event_source_client/src/state_connecting.dart';
import 'package:launchdarkly_event_source_client/src/state_idle.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('Test connecting to connected when 200OK', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final svo =
        TestUtils.makeMockStateValues(transitionSink: transitionController);

    expectLater(transitionController.stream,
        emitsInOrder([StateConnecting, StateConnected]));
    await StateConnecting.run(svo);
  });

  test(
      'a recoverable error backs off and reports SseHttpError(recoverable: '
      'true) with its headers', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final eventController = StreamController<Event>.broadcast();

    final svo = TestUtils.makeMockStateValues(
        transitionSink: transitionController,
        eventSink: eventController,
        clientFactory: () => TestUtils.makeMockHttpClient(
            httpStatusCode: 503, headers: const {'x-ld-fd-fallback': 'true'}));

    expectLater(transitionController.stream,
        emitsInOrder([StateConnecting, StateBackoff]));
    expectLater(
        eventController.stream,
        emitsError(isA<SseHttpError>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.recoverable, 'recoverable', true)
            .having((e) => e.headers['x-ld-fd-fallback'], 'directive header',
                'true')));
    await StateConnecting.run(svo);
  });

  test(
      'an unrecoverable error goes idle and reports SseHttpError(recoverable: '
      'false) with its headers', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final eventController = StreamController<Event>.broadcast();

    final svo = TestUtils.makeMockStateValues(
        transitionSink: transitionController,
        eventSink: eventController,
        clientFactory: () => TestUtils.makeMockHttpClient(
            httpStatusCode: 401, headers: const {'x-ld-fd-fallback': 'true'}));

    expectLater(transitionController.stream,
        emitsInOrder([StateConnecting, StateIdle]));
    expectLater(
        eventController.stream,
        emitsError(isA<SseHttpError>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.recoverable, 'recoverable', false)
            .having((e) => e.headers['x-ld-fd-fallback'], 'directive header',
                'true')));
    await StateConnecting.run(svo);
  });

  test('Test connecting cleans up when control stream closed', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final connectionController = StreamController<bool>.broadcast();

    // blocking client to stop us from going to connected state
    final svo = TestUtils.makeMockStateValues(
        connectionDesired: connectionController.stream,
        transitionSink: transitionController,
        clientFactory: () => TestUtils.makeMockHttpClient(blocking: true));

    // should not block for any duration of time
    connectionController.close();
    expectLater(transitionController.stream,
        emitsInOrder([StateConnecting, StateIdle]));
    await StateConnecting.run(svo);
  });

  MockClient throwingClient(String message) =>
      MockClient.streaming((request, body) => throw ClientException(message));

  final failures = [
    (
      'a 503 response',
      () => TestUtils.makeMockHttpClient(httpStatusCode: 503),
      isA<SseHttpError>().having((e) => e.recoverable, 'recoverable', true)
    ),
    (
      'a wrong content type',
      () => TestUtils.makeMockHttpClient(
          headers: const {'content-type': 'text/html'}),
      isA<SseConnectionError>()
    ),
    (
      'a connect timeout',
      () => TestUtils.makeMockHttpClient(blocking: true),
      isA<SseConnectionError>()
    ),
    (
      'a transport error',
      () => throwingClient('connection reset'),
      isA<SseConnectionError>()
    ),
    (
      'a redirect loop',
      () => throwingClient('Redirect loop detected'),
      isA<SseConnectionError>()
    ),
  ];

  for (final (name, clientFactory, error) in failures) {
    test('$name goes idle and reports an error when autoReconnect is off',
        () async {
      final transitionController = StreamController<dynamic>.broadcast();
      final eventController = StreamController<Event>.broadcast();

      final svo = TestUtils.makeMockStateValues(
          transitionSink: transitionController,
          eventSink: eventController,
          clientFactory: clientFactory,
          autoReconnect: false);

      // The client stops and reports the failure.
      expectLater(transitionController.stream,
          emitsInOrder([StateConnecting, StateIdle]));
      expectLater(eventController.stream, emitsError(error));
      // Connect with a client that fails.
      await StateConnecting.run(svo);
    });
  }

  for (final (name, clientFactory, _) in failures.sublist(1, 4)) {
    test('$name backs off when autoReconnect is on', () async {
      final transitionController = StreamController<dynamic>.broadcast();

      final svo = TestUtils.makeMockStateValues(
          transitionSink: transitionController, clientFactory: clientFactory);

      // The client retries.
      expectLater(transitionController.stream,
          emitsInOrder([StateConnecting, StateBackoff]));
      // Connect with a client that fails.
      await StateConnecting.run(svo);
    });
  }

  for (final (name, statusCode, headers) in [
    ('an error status', 503, TestUtils.defaultHeaders),
    ('a wrong content type', 200, const {'content-type': 'text/html'}),
  ]) {
    test('$name closes the HTTP client when autoReconnect is off', () async {
      final client = _RecordingClient(TestUtils.makeMockHttpClient(
          httpStatusCode: statusCode, headers: headers));

      final svo = TestUtils.makeMockStateValues(
          clientFactory: () => client, autoReconnect: false);

      // Connect with a client that fails.
      await StateConnecting.run(svo);
      // The state releases the HTTP client.
      expect(client.closed, isTrue);
    });
  }
}

/// Sends requests with another client and records whether it is closed.
class _RecordingClient extends BaseClient {
  final Client _inner;
  var closed = false;

  _RecordingClient(this._inner);

  @override
  Future<StreamedResponse> send(BaseRequest request) => _inner.send(request);

  @override
  void close() => closed = true;
}
