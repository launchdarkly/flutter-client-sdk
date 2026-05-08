import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_base.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogAdapter extends Mock implements LDLogAdapter {}

TestSseClient makeSse() => SSEClient.testClient(Uri.parse('/test'), const {});

void emitOpen(TestSseClient sse, {Map<String, String>? headers}) {
  sse.emitEvent(OpenEvent(
    headers: headers == null ? null : UnmodifiableMapView(headers),
  ));
}

void emitMessage(TestSseClient sse, String type, String data, {String? id}) {
  sse.emitEvent(MessageEvent(type, data, id));
}

String serverIntent({String intentCode = 'xfer-full', int target = 1}) =>
    jsonEncode({
      'payloads': [
        {
          'id': 'p1',
          'target': target,
          'intentCode': intentCode,
          'reason': 'test',
        }
      ]
    });

String putObject({
  String key = 'flag-a',
  int version = 1,
}) =>
    jsonEncode({
      'kind': 'flag-eval',
      'key': key,
      'version': version,
      'object': {'value': true, 'version': version, 'variation': 0},
    });

String payloadTransferred({String state = 'sel-1', int version = 1}) =>
    jsonEncode({
      'state': state,
      'version': version,
    });

void emitFullPayload(TestSseClient sse,
    {String state = 'sel-1', String flagKey = 'flag-a'}) {
  emitMessage(sse, 'server-intent', serverIntent());
  emitMessage(sse, 'put-object', putObject(key: flagKey));
  emitMessage(sse, 'payload-transferred', payloadTransferred(state: state));
}

FDv2StreamingBase makeBase(
  TestSseClient sse, {
  Future<FDv2SourceResult> Function()? pingHandler,
  DateTime Function()? now,
}) {
  return FDv2StreamingBase(
    sseClient: sse,
    pingHandler: pingHandler ??
        () async => FDv2SourceResults.interrupted(message: 'no ping handler'),
    logger: LDLogger(level: LDLogLevel.error),
    now: now,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });

  group('connection lifecycle', () {
    test('opens the SSE stream on first listen', () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];

      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      // No emission yet -- nothing has come in over the SSE stream.
      expect(emissions, isEmpty);

      // Drive a full xfer-full sequence and confirm the resulting
      // ChangeSetResult is emitted.
      emitFullPayload(sse);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, hasLength(1));
      expect(emissions.single, isA<ChangeSetResult>());

      await sub.cancel();
    });

    test(
        'subscription cancel tears down the SSE client without emitting '
        'shutdown', () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      await Future<void>.delayed(Duration.zero);

      expect(sse.isClosed, isTrue);
      expect(emissions.whereType<StatusResult>(), isEmpty);
    });

    test('close() emits shutdown then closes the stream', () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final done = Completer<void>();
      base.results.listen(emissions.add, onDone: done.complete);
      await Future<void>.delayed(Duration.zero);

      base.close();
      await done.future;

      expect(emissions, hasLength(1));
      expect((emissions.single as StatusResult).state,
          equals(SourceState.shutdown));
      expect(sse.isClosed, isTrue);
    });

    test('close() is idempotent', () async {
      final sse = makeSse();
      final base = makeBase(sse);
      base.close();
      expect(() => base.close(), returnsNormally);
    });

    test('close() is safe to call from a listener reacting to a goodbye',
        () async {
      // The orchestrator can legitimately react to a goodbye result
      // by calling base.close(). That path must not race with the
      // self-close the goodbye branch already does internally.
      final sse = makeSse();
      final base = makeBase(sse);
      Object? caught;
      runZonedGuarded(() {
        base.results.listen((event) {
          if (event is StatusResult && event.state == SourceState.goodbye) {
            base.close();
          }
        });
      }, (err, _) => caught = err);

      await Future<void>.delayed(Duration.zero);
      emitMessage(sse, 'server-intent', serverIntent());
      emitMessage(sse, 'goodbye', jsonEncode({'reason': 'maintenance'}));
      // Yield enough times for the listener and any async work to settle.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(caught, isNull,
          reason:
              'close() from onData on a goodbye must not throw, got $caught');
      expect(sse.isClosed, isTrue);
    });

    test(
        'close() is safe to call from a listener reacting to an FDv1 '
        'fallback', () async {
      // Same race risk as the goodbye case, but for the fdv1-fallback
      // terminal branch.
      final sse = makeSse();
      final base = makeBase(sse);
      Object? caught;
      runZonedGuarded(() {
        base.results.listen((event) {
          if (event is StatusResult && event.fdv1Fallback) {
            base.close();
          }
        });
      }, (err, _) => caught = err);

      await Future<void>.delayed(Duration.zero);
      emitOpen(sse, headers: {'x-ld-fd-fallback': 'true'});
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(caught, isNull,
          reason:
              'close() from onData on fallback must not throw, got $caught');
      expect(sse.isClosed, isTrue);
    });
  });

  group('event handling', () {
    test('xfer-full sequence produces ChangeSetResult with full payload',
        () async {
      final sse = makeSse();
      final fixedNow = DateTime.utc(2026, 1, 1);
      final base = makeBase(sse, now: () => fixedNow);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      emitFullPayload(sse, state: 'sel-99', flagKey: 'k1');
      await Future<void>.delayed(Duration.zero);

      expect(emissions, hasLength(1));
      final cs = emissions.single as ChangeSetResult;
      expect(cs.payload.type, equals(PayloadType.full));
      expect(cs.payload.selector.state, equals('sel-99'));
      expect(cs.payload.updates.single.key, equals('k1'));
      expect(cs.persist, isTrue);
      expect(cs.freshness, equals(fixedNow));

      await sub.cancel();
    });

    test('environmentId from x-ld-envid header rides on the ChangeSetResult',
        () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      emitOpen(sse, headers: {'x-ld-envid': 'env-abc'});
      emitFullPayload(sse);
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as ChangeSetResult).environmentId,
          equals('env-abc'));

      await sub.cancel();
    });

    test('goodbye event closes the source and emits a goodbye result',
        () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final done = Completer<void>();
      base.results.listen(emissions.add, onDone: done.complete);
      await Future<void>.delayed(Duration.zero);

      emitMessage(sse, 'server-intent', serverIntent());
      emitMessage(sse, 'goodbye', jsonEncode({'reason': 'maintenance'}));
      await done.future;

      expect(emissions, hasLength(1));
      expect((emissions.single as StatusResult).state,
          equals(SourceState.goodbye));
      expect(sse.isClosed, isTrue);
    });

    test('unparseable event data is reported as interrupted, no throw',
        () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      emitMessage(sse, 'put-object', 'not json');
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as StatusResult).state,
          equals(SourceState.interrupted));

      await sub.cancel();
    });

    test(
        'malformed-shape event data that passes the Map check but fails '
        'inside processEvent is reported as interrupted, no unhandled async',
        () async {
      // The data is a JSON object, but its inner structure violates
      // the FDv2 protocol: payloads must be a list, not a string. The
      // List<dynamic> cast inside protocol_types.dart throws TypeError
      // synchronously from processEvent. The streaming source must
      // catch it and surface as interrupted, not let it become an
      // unhandled async exception.
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      Object? caughtAsync;
      late final StreamSubscription sub;
      runZonedGuarded(() {
        sub = base.results.listen(emissions.add);
      }, (err, _) => caughtAsync = err);
      await Future<void>.delayed(Duration.zero);

      emitMessage(sse, 'server-intent', jsonEncode({'payloads': 'not-a-list'}));
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(caughtAsync, isNull,
          reason: 'malformed inner shape must not become unhandled async, '
              'got $caughtAsync');
      expect((emissions.single as StatusResult).state,
          equals(SourceState.interrupted));

      await sub.cancel();
    });

    test('non-object event data is reported as interrupted, no throw',
        () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      emitMessage(sse, 'server-intent', '[1,2,3]');
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as StatusResult).state,
          equals(SourceState.interrupted));

      await sub.cancel();
    });

    test(
        'an SSE reconnect resets the protocol handler so partial transfer '
        'state from the previous connection does not bleed into the new one',
        () async {
      // Connection 1: server-intent + put-object, then the connection
      // drops BEFORE payload-transferred. The handler is mid-payload
      // with one accumulated update.
      //
      // Connection 2 (auto-reconnect, fresh OpenEvent on the same SSE
      // subscriber): a Last-Event-ID resumption could have the server
      // skip server-intent and continue with put-object directly.
      // Without a per-OpenEvent handler reset, the new put-object
      // accumulates on top of the stale buffer. The eventual
      // payload-transferred would emit BOTH puts as one payload.
      //
      // With the reset, the new OpenEvent rebuilds the handler. Absent
      // a server-intent the new put-object lands on an inactive
      // handler and is rejected; the payload-transferred surfaces as a
      // protocol error rather than as a corrupted ChangeSet.
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      emitOpen(sse);
      emitMessage(sse, 'server-intent', serverIntent());
      emitMessage(sse, 'put-object', putObject(key: 'old-flag', version: 1));

      // Reconnect. Server skips server-intent (Last-Event-ID resume).
      emitOpen(sse);
      emitMessage(sse, 'put-object', putObject(key: 'new-flag', version: 2));
      emitMessage(sse, 'payload-transferred', payloadTransferred());

      await Future<void>.delayed(Duration.zero);

      for (final result in emissions.whereType<ChangeSetResult>()) {
        final keys = result.payload.updates.map((u) => u.key).toSet();
        expect(keys, isNot(contains('old-flag')),
            reason: 'old-flag from the previous connection bled into '
                "the new connection's payload");
      }

      await sub.cancel();
    });

    test('SSE transport error is reported as interrupted', () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      sse.emitError(error: Exception('connection dropped'));
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as StatusResult).state,
          equals(SourceState.interrupted));

      await sub.cancel();
    });

    test(
        'SSE transport error log records do not echo the request URL '
        'or any other detail of the underlying exception', () async {
      // http.ClientException's toString format is
      // 'ClientException: <msg>, uri=<full-url>'. The URL embeds the
      // base64-encoded context in GET mode, which is reversible.
      // The streaming source must categorize the error and log only
      // the sanitized form, like the polling sibling does.
      final adapter = MockLogAdapter();
      when(() => adapter.log(any())).thenReturn(null);
      final logger = LDLogger(adapter: adapter, level: LDLogLevel.debug);

      final sse = makeSse();
      final base = FDv2StreamingBase(
        sseClient: sse,
        pingHandler: () async =>
            FDv2SourceResults.interrupted(message: 'no ping'),
        logger: logger,
      );
      final sub = base.results.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      const secret = 'SECRET-ENCODED-CONTEXT';
      sse.emitError(
        error: http.ClientException('Connection refused',
            Uri.parse('https://example.test/sdk/stream/eval/$secret')),
      );
      await Future<void>.delayed(Duration.zero);

      final records = verify(() => adapter.log(captureAny())).captured;
      for (final record in records) {
        expect((record as LDLogRecord).message, isNot(contains(secret)));
      }

      await sub.cancel();
    });
  });

  group('FDv1 fallback header on connect', () {
    test(
        'x-ld-fd-fallback: true on the OpenEvent emits terminalError and '
        'closes', () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final done = Completer<void>();
      base.results.listen(emissions.add, onDone: done.complete);
      await Future<void>.delayed(Duration.zero);

      emitOpen(sse, headers: {'x-ld-fd-fallback': 'true'});
      await done.future;

      expect(emissions, hasLength(1));
      final status = emissions.single as StatusResult;
      expect(status.state, equals(SourceState.terminalError));
      expect(status.fdv1Fallback, isTrue);
      expect(sse.isClosed, isTrue);
    });

    test('fallback header is matched case-insensitively', () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      emitOpen(sse, headers: {'x-ld-fd-fallback': 'TRUE'});
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as StatusResult).fdv1Fallback, isTrue);

      await sub.cancel();
    });

    test('fallback header value other than true is ignored', () async {
      final sse = makeSse();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      emitOpen(sse, headers: {'x-ld-fd-fallback': 'false'});
      emitFullPayload(sse);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.single, isA<ChangeSetResult>());
      expect(emissions.single.fdv1Fallback, isFalse);

      await sub.cancel();
    });
  });

  group('legacy ping bridge', () {
    test(
        'ping event invokes the PingHandler and forwards its result to '
        'the stream', () async {
      var pingCallCount = 0;
      final pingResult = ChangeSetResult(
        payload: const Payload(type: PayloadType.full, updates: []),
        persist: true,
        freshness: DateTime.utc(2026, 1, 1),
      );
      final sse = makeSse();
      final base = makeBase(
        sse,
        pingHandler: () async {
          pingCallCount++;
          return pingResult;
        },
      );
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      emitMessage(sse, 'ping', '');
      await Future<void>.delayed(Duration.zero);

      expect(pingCallCount, equals(1));
      expect(emissions, hasLength(1));
      expect(identical(emissions.single, pingResult), isTrue);

      await sub.cancel();
    });

    test(
        'consecutive ping events do not spawn concurrent PingHandler '
        'invocations -- excess pings are dropped while one is in flight',
        () async {
      // Two pings back-to-back must not result in two concurrent polls.
      // The slow poll's result could otherwise overwrite the fast one's
      // (out-of-order) and the polling endpoint sees DoS amplification.
      // FDv2 ping semantic is "go re-poll" -- a single in-flight poll
      // already satisfies it.
      var concurrent = 0;
      var maxConcurrent = 0;
      var totalCalls = 0;
      final firstCallGate = Completer<void>();
      final firstCallReleased = Completer<void>();
      final sse = makeSse();
      final base = makeBase(
        sse,
        pingHandler: () async {
          totalCalls++;
          concurrent++;
          if (concurrent > maxConcurrent) maxConcurrent = concurrent;
          if (!firstCallGate.isCompleted) firstCallGate.complete();
          // Hold the first call open until the test releases it.
          await firstCallReleased.future;
          concurrent--;
          return FDv2SourceResults.interrupted(message: 'ok');
        },
      );
      final sub = base.results.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      emitMessage(sse, 'ping', '');
      // Wait for the first call to enter the handler.
      await firstCallGate.future;
      // Fire the second ping while the first is still in flight.
      emitMessage(sse, 'ping', '');
      await Future<void>.delayed(Duration.zero);
      // Release the held call so it can return.
      firstCallReleased.complete();
      await Future<void>.delayed(Duration.zero);

      expect(maxConcurrent, equals(1),
          reason: 'concurrent ping handler invocations are not allowed');
      expect(totalCalls, equals(1),
          reason: 'the second ping must be dropped while the first is '
              'still in flight');

      await sub.cancel();
    });

    test('PingHandler throwing is treated as interrupted, no propagation',
        () async {
      final sse = makeSse();
      final base = makeBase(
        sse,
        pingHandler: () async {
          throw StateError('boom');
        },
      );
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      emitMessage(sse, 'ping', '');
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as StatusResult).state,
          equals(SourceState.interrupted));

      await sub.cancel();
    });
  });
}
