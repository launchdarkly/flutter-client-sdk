// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:launchdarkly_event_source_client/src/http_consts.dart';
import 'package:launchdarkly_event_source_client/src/sse_client_http.dart';
import 'package:launchdarkly_event_source_client/src/state_backoff.dart';
import 'package:launchdarkly_event_source_client/src/state_stopped.dart';
import 'package:test/test.dart';

/// A content type from the server. The client must not log it.
const _serverContentType = 'text/html; injected-text';

const _eventStreamHeaders = {
  HttpHeaders.contentTypeHeader: MimeTypes.textEventStream
};

/// Each case makes one kind of failure on every request.
final class _FailureCase {
  final String name;
  final http.Client Function() clientFactory;
  final Matcher error;
  final Duration connectTimeout;
  final Duration readTimeout;

  _FailureCase(this.name, this.clientFactory, this.error,
      {this.connectTimeout = const Duration(days: 1),
      this.readTimeout = const Duration(days: 1)});
}

http.Client _statusClient(int status) => MockClient.streaming(
    (request, body) async => http.StreamedResponse(const Stream.empty(), status,
        headers: const {'x-ld-fd-fallback': 'true'}));

http.Client _contentTypeClient() =>
    MockClient.streaming((request, body) async => http.StreamedResponse(
        Stream.value(utf8.encode('{}')), 200,
        headers: const {HttpHeaders.contentTypeHeader: _serverContentType}));

http.Client _blockingClient() => MockClient.streaming((request, body) async {
      await Completer<void>().future;
      throw StateError('unreachable');
    });

http.Client _silentStreamClient() =>
    MockClient.streaming((request, body) async => http.StreamedResponse(
        StreamController<List<int>>().stream, 200,
        headers: _eventStreamHeaders));

http.Client _transportErrorClient() => MockClient.streaming(
    (request, body) async => throw http.ClientException('connection reset'));

http.Client _closingStreamClient() =>
    MockClient.streaming((request, body) async => http.StreamedResponse(
        Stream.value(utf8.encode('event:put\ndata:hello\n\n')), 200,
        headers: _eventStreamHeaders));

final _failureCases = [
  _FailureCase(
      'a 401 response',
      () => _statusClient(401),
      isA<SseHttpError>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.headers['x-ld-fd-fallback'], 'header', 'true')),
  _FailureCase('a 503 response', () => _statusClient(503),
      isA<SseHttpError>().having((e) => e.statusCode, 'statusCode', 503)),
  _FailureCase(
      'a connect timeout',
      _blockingClient,
      isA<SseTimeoutError>()
          .having((e) => e.phase, 'phase', SseTimeoutPhase.connect),
      connectTimeout: const Duration(milliseconds: 10)),
  _FailureCase(
      'a read timeout',
      _silentStreamClient,
      isA<SseTimeoutError>()
          .having((e) => e.phase, 'phase', SseTimeoutPhase.read),
      readTimeout: const Duration(milliseconds: 10)),
  _FailureCase(
      'a transport error', _transportErrorClient, isA<SseTransportError>()),
  _FailureCase(
      'a wrong content type',
      _contentTypeClient,
      isA<SseContentTypeError>().having(
          (e) => e.toString(), 'toString', isNot(contains('injected-text')))),
  _FailureCase('a stream closed by the server', _closingStreamClient,
      isA<SseStreamClosedError>()),
];

HttpSseClient _makeClient(_FailureCase failure,
    {required bool autoReconnect,
    required StreamController<dynamic> transitions,
    void Function()? onRequest,
    EventSourceLogger logger = const NoOpLogger()}) {
  return HttpSseClient.internal(Uri.parse('/path'), {'put'}, {},
      failure.connectTimeout, failure.readTimeout, transitions.sink, () {
    onRequest?.call();
    return failure.clientFactory();
  }, math.Random(), null, 'GET', logger, autoReconnect: autoReconnect);
}

/// Keeps every message that the client logs.
final class _RecordingLogger implements EventSourceLogger {
  final List<String> messages = [];

  @override
  void debug(String message) => messages.add(message);

  @override
  void info(String message) => messages.add(message);

  @override
  void warn(String message) => messages.add(message);

  @override
  void error(String message) => messages.add(message);
}

void main() {
  for (final autoReconnect in [true, false]) {
    test(
        'it does not log the content type from the server '
        '(autoReconnect: $autoReconnect)', () async {
      final logger = _RecordingLogger();
      final client = _makeClient(
          _FailureCase('a wrong content type', _contentTypeClient,
              isA<SseContentTypeError>()),
          autoReconnect: autoReconnect,
          transitions: StreamController<dynamic>.broadcast(),
          logger: logger);

      final firstError = Completer<Object>();
      client.stream.listen((_) {}, onError: (Object err) {
        if (!firstError.isCompleted) {
          firstError.complete(err);
        }
      });
      await firstError.future;
      await client.close();

      expect(logger.messages, isNotEmpty);
      expect(logger.messages, everyElement(isNot(contains('injected-text'))));
    });
  }

  group('with automatic reconnect off', () {
    for (final failure in _failureCases) {
      test('it reports ${failure.name} once and stops', () async {
        final transitions = StreamController<dynamic>.broadcast();
        final seenTransitions = <dynamic>[];
        transitions.stream.listen(seenTransitions.add);
        var requests = 0;
        final client = _makeClient(failure,
            autoReconnect: false,
            transitions: transitions,
            onRequest: () => requests++);

        final errors = <Object>[];
        client.stream.listen((_) {}, onError: errors.add);

        await Future<void>.delayed(const Duration(milliseconds: 1500));

        expect(errors, [failure.error]);
        expect(requests, 1);
        expect(seenTransitions, contains(StateStopped));
        expect(seenTransitions, isNot(contains(StateBackoff)));
        await client.close();
      });
    }

    test('it ignores a restart request', () async {
      final transitions = StreamController<dynamic>.broadcast();
      final seenTransitions = <dynamic>[];
      transitions.stream.listen(seenTransitions.add);
      final client = _makeClient(
          _FailureCase('an open stream', _silentStreamClient, isA<Object>()),
          autoReconnect: false,
          transitions: transitions);

      final events = <Event>[];
      client.stream.listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      client.restart();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(events, [isA<OpenEvent>()]);
      expect(seenTransitions, isNot(contains(StateBackoff)));
      await client.close();
    });
  });

  group('with automatic reconnect on', () {
    for (final failure in _failureCases) {
      test('it reports ${failure.name} once per attempt', () async {
        final transitions = StreamController<dynamic>.broadcast();
        final client =
            _makeClient(failure, autoReconnect: true, transitions: transitions);

        final firstError = Completer<Object>();
        client.stream.listen((_) {}, onError: (Object err) {
          if (!firstError.isCompleted) {
            firstError.complete(err);
          }
        });

        expect(await firstError.future, failure.error);
        await client.close();
      });
    }

    test('it reconnects after the server closes the stream', () async {
      final transitions = StreamController<dynamic>.broadcast();
      var requests = 0;
      final secondRequest = Completer<void>();
      final client = _makeClient(
          _FailureCase('a stream closed by the server', _closingStreamClient,
              isA<SseStreamClosedError>()),
          autoReconnect: true,
          transitions: transitions, onRequest: () {
        requests++;
        if (requests == 2) {
          secondRequest.complete();
        }
      });

      client.stream.listen((_) {}, onError: (_) {});

      await secondRequest.future.timeout(const Duration(seconds: 5));
      await client.close();
    });

    test('it marks a status it retries as recoverable', () async {
      final transitions = StreamController<dynamic>.broadcast();
      final client = _makeClient(
          _FailureCase(
              'a 503 response', () => _statusClient(503), isA<SseHttpError>()),
          autoReconnect: true,
          transitions: transitions);

      final firstError = Completer<Object>();
      client.stream.listen((_) {}, onError: (Object err) {
        if (!firstError.isCompleted) {
          firstError.complete(err);
        }
      });

      expect(
          await firstError.future,
          isA<SseHttpError>()
              .having((e) => e.recoverable, 'recoverable', true));
      await client.close();
    });

    test('it marks a status as not recoverable when it does not reconnect',
        () async {
      final transitions = StreamController<dynamic>.broadcast();
      final client = _makeClient(
          _FailureCase(
              'a 503 response', () => _statusClient(503), isA<SseHttpError>()),
          autoReconnect: false,
          transitions: transitions);

      final firstError = Completer<Object>();
      client.stream.listen((_) {}, onError: firstError.complete);

      expect(
          await firstError.future,
          isA<SseHttpError>()
              .having((e) => e.recoverable, 'recoverable', false));
      await client.close();
    });
  });

  group('when the owner closes the client', () {
    for (final autoReconnect in [true, false]) {
      test('it reports nothing (autoReconnect: $autoReconnect)', () async {
        final transitions = StreamController<dynamic>.broadcast();
        final client = _makeClient(
            _FailureCase('an open stream', _silentStreamClient, isA<Object>()),
            autoReconnect: autoReconnect,
            transitions: transitions);

        final errors = <Object>[];
        final done = Completer<void>();
        client.stream
            .listen((_) {}, onError: errors.add, onDone: done.complete);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await client.close();
        await done.future;
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(errors, isEmpty);
      });
    }
  });
}
