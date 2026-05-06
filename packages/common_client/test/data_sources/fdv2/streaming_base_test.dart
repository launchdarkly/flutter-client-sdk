import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_base.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

/// Fake SSE client backed by a controllable [StreamController]. Tests
/// drive the SSE stream by calling [emitOpen], [emitMessage], or
/// [emitError]. Calls to [close] complete the [closed] future so tests
/// can assert teardown happened.
class FakeSseClient implements SSEClient {
  final StreamController<Event> _controller = StreamController<Event>();
  final Completer<void> closed = Completer<void>();
  int restartCount = 0;

  void emitOpen({Map<String, String>? headers}) {
    _controller.add(OpenEvent(
      headers: headers == null ? null : UnmodifiableMapView(headers),
    ));
  }

  void emitMessage(String type, String data, {String? id}) {
    _controller.add(MessageEvent(type, data, id));
  }

  void emitError(Object err) {
    _controller.addError(err);
  }

  @override
  Stream<Event> get stream => _controller.stream;

  @override
  Future<void> close() async {
    if (!closed.isCompleted) closed.complete();
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  void restart() {
    restartCount++;
  }

  @override
  bool hasCapability(SSECapability capability) => true;
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

void emitFullPayload(FakeSseClient sse,
    {String state = 'sel-1', String flagKey = 'flag-a'}) {
  sse.emitMessage('server-intent', serverIntent());
  sse.emitMessage('put-object', putObject(key: flagKey));
  sse.emitMessage('payload-transferred', payloadTransferred(state: state));
}

FDv2StreamingBase makeBase(
  FakeSseClient sse, {
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
  group('connection lifecycle', () {
    test('opens the SSE stream on first listen', () async {
      final sse = FakeSseClient();
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
      final sse = FakeSseClient();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      await Future<void>.delayed(Duration.zero);

      expect(sse.closed.isCompleted, isTrue);
      expect(emissions.whereType<StatusResult>(), isEmpty);
    });

    test('close() emits shutdown then closes the stream', () async {
      final sse = FakeSseClient();
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
      expect(sse.closed.isCompleted, isTrue);
    });

    test('close() is idempotent', () async {
      final sse = FakeSseClient();
      final base = makeBase(sse);
      base.close();
      expect(() => base.close(), returnsNormally);
    });
  });

  group('event handling', () {
    test('xfer-full sequence produces ChangeSetResult with full payload',
        () async {
      final sse = FakeSseClient();
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
      final sse = FakeSseClient();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      sse.emitOpen(headers: {'x-ld-envid': 'env-abc'});
      emitFullPayload(sse);
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as ChangeSetResult).environmentId,
          equals('env-abc'));

      await sub.cancel();
    });

    test('goodbye event closes the source and emits a goodbye result',
        () async {
      final sse = FakeSseClient();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final done = Completer<void>();
      base.results.listen(emissions.add, onDone: done.complete);
      await Future<void>.delayed(Duration.zero);

      sse.emitMessage('server-intent', serverIntent());
      sse.emitMessage('goodbye', jsonEncode({'reason': 'maintenance'}));
      await done.future;

      expect(emissions, hasLength(1));
      expect((emissions.single as StatusResult).state,
          equals(SourceState.goodbye));
      expect(sse.closed.isCompleted, isTrue);
    });

    test('unparseable event data is reported as interrupted, no throw',
        () async {
      final sse = FakeSseClient();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      sse.emitMessage('put-object', 'not json');
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as StatusResult).state,
          equals(SourceState.interrupted));

      await sub.cancel();
    });

    test('non-object event data is reported as interrupted, no throw',
        () async {
      final sse = FakeSseClient();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      sse.emitMessage('server-intent', '[1,2,3]');
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as StatusResult).state,
          equals(SourceState.interrupted));

      await sub.cancel();
    });

    test('SSE transport error is reported as interrupted', () async {
      final sse = FakeSseClient();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      sse.emitError(Exception('connection dropped'));
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as StatusResult).state,
          equals(SourceState.interrupted));

      await sub.cancel();
    });
  });

  group('FDv1 fallback header on connect', () {
    test(
        'x-ld-fd-fallback: true on the OpenEvent emits terminalError and '
        'closes', () async {
      final sse = FakeSseClient();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final done = Completer<void>();
      base.results.listen(emissions.add, onDone: done.complete);
      await Future<void>.delayed(Duration.zero);

      sse.emitOpen(headers: {'x-ld-fd-fallback': 'true'});
      await done.future;

      expect(emissions, hasLength(1));
      final status = emissions.single as StatusResult;
      expect(status.state, equals(SourceState.terminalError));
      expect(status.fdv1Fallback, isTrue);
      expect(sse.closed.isCompleted, isTrue);
    });

    test('fallback header is matched case-insensitively', () async {
      final sse = FakeSseClient();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      sse.emitOpen(headers: {'x-ld-fd-fallback': 'TRUE'});
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as StatusResult).fdv1Fallback, isTrue);

      await sub.cancel();
    });

    test('fallback header value other than true is ignored', () async {
      final sse = FakeSseClient();
      final base = makeBase(sse);
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      sse.emitOpen(headers: {'x-ld-fd-fallback': 'false'});
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
      final sse = FakeSseClient();
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

      sse.emitMessage('ping', '');
      await Future<void>.delayed(Duration.zero);

      expect(pingCallCount, equals(1));
      expect(emissions, hasLength(1));
      expect(identical(emissions.single, pingResult), isTrue);

      await sub.cancel();
    });

    test('PingHandler throwing is treated as interrupted, no propagation',
        () async {
      final sse = FakeSseClient();
      final base = makeBase(
        sse,
        pingHandler: () async {
          throw StateError('boom');
        },
      );
      final emissions = <FDv2SourceResult>[];
      final sub = base.results.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      sse.emitMessage('ping', '');
      await Future<void>.delayed(Duration.zero);

      expect((emissions.single as StatusResult).state,
          equals(SourceState.interrupted));

      await sub.cancel();
    });
  });
}
