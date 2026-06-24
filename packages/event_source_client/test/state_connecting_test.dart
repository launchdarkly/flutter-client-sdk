// ignore_for_file: close_sinks

import 'dart:async';

import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart'
    show Event, SseHttpError;
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
}
