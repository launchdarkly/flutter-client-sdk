// ignore_for_file: close_sinks

import 'dart:async';

import 'package:http/http.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:launchdarkly_event_source_client/src/state_connecting.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('uses the fixed uri when no provider is given', () async {
    final requestedPaths = <String>[];
    final svo = TestUtils.makeMockStateValues(
        uri: Uri.parse('/fixed'),
        clientFactory: () => TestUtils.makeMockHttpClient(
            onRequest: (BaseRequest request) =>
                requestedPaths.add(request.url.path)));

    await StateConnecting.run(svo);

    expect(requestedPaths, equals(['/fixed']));
  });

  test('invokes the uriProvider for each connection attempt', () async {
    final requestedPaths = <String>[];
    var attempt = 0;
    final svo = TestUtils.makeMockStateValues(
        uri: Uri.parse('/unused'),
        uriProvider: () => Uri.parse('/attempt-${++attempt}'),
        clientFactory: () => TestUtils.makeMockHttpClient(
            onRequest: (BaseRequest request) =>
                requestedPaths.add(request.url.path)));

    await StateConnecting.run(svo);
    await StateConnecting.run(svo);

    expect(requestedPaths, equals(['/attempt-1', '/attempt-2']));
  });

  test(
      'reports SseHttpError with the status code and headers '
      'for non-retryable status codes', () async {
    final eventsController = StreamController<Event>.broadcast();
    final svo = TestUtils.makeMockStateValues(
        eventSink: eventsController,
        clientFactory: () => TestUtils.makeMockHttpClient(
            httpStatusCode: 401, headers: {'x-ld-fd-fallback': 'true'}));

    final expectation = expectLater(
        eventsController.stream,
        emitsError(isA<SseHttpError>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.recoverable, 'recoverable', false)
            .having((error) => error.headers['x-ld-fd-fallback'],
                'fallback header', 'true')));

    await StateConnecting.run(svo);
    await expectation;
  });
}
