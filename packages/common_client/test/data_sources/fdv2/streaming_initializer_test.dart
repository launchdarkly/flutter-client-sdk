import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_base.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_initializer.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

class FakeSseClient implements SSEClient {
  final StreamController<Event> _controller = StreamController<Event>();
  bool _closed = false;

  void emitMessage(String type, String data) {
    _controller.add(MessageEvent(type, data, null));
  }

  void emitOpen({Map<String, String>? headers}) {
    _controller.add(OpenEvent(
        headers: headers == null ? null : UnmodifiableMapView(headers)));
  }

  bool get sseClosed => _closed;

  @override
  Stream<Event> get stream => _controller.stream;

  @override
  Future<void> close() async {
    _closed = true;
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  void restart() {}

  @override
  bool hasCapability(SSECapability capability) => true;
}

void emitFullPayload(FakeSseClient sse, {String state = 'sel-1'}) {
  sse.emitMessage(
    'server-intent',
    jsonEncode({
      'payloads': [
        {
          'id': 'p1',
          'target': 1,
          'intentCode': 'xfer-full',
          'reason': 'test',
        }
      ]
    }),
  );
  sse.emitMessage(
    'put-object',
    jsonEncode({
      'kind': 'flag-eval',
      'key': 'k',
      'version': 1,
      'object': {'value': true, 'version': 1, 'variation': 0},
    }),
  );
  sse.emitMessage(
    'payload-transferred',
    jsonEncode({'state': state, 'version': 1}),
  );
}

FDv2StreamingBase makeBase(FakeSseClient sse) => FDv2StreamingBase(
      sseClient: sse,
      pingHandler: () async =>
          FDv2SourceResults.interrupted(message: 'no ping'),
      logger: LDLogger(level: LDLogLevel.error),
    );

void main() {
  test('returns the first ChangeSetResult and tears the connection down',
      () async {
    final sse = FakeSseClient();
    final init = FDv2StreamingInitializer(base: makeBase(sse));

    final future = init.run();
    // Yield once so run subscribes to the base.
    await Future<void>.delayed(Duration.zero);

    emitFullPayload(sse, state: 'sel-init');
    final result = await future;

    expect(result, isA<ChangeSetResult>());
    expect(
        (result as ChangeSetResult).payload.selector.state, equals('sel-init'));
    expect(sse.sseClosed, isTrue);
  });

  test('surfaces a goodbye result as the first emission', () async {
    final sse = FakeSseClient();
    final init = FDv2StreamingInitializer(base: makeBase(sse));
    final future = init.run();
    await Future<void>.delayed(Duration.zero);

    sse.emitMessage(
      'server-intent',
      jsonEncode({
        'payloads': [
          {
            'id': 'p1',
            'target': 1,
            'intentCode': 'xfer-full',
            'reason': 'test',
          }
        ]
      }),
    );
    sse.emitMessage('goodbye', jsonEncode({'reason': 'maintenance'}));

    final result = await future;
    expect((result as StatusResult).state, equals(SourceState.goodbye));
    expect(sse.sseClosed, isTrue);
  });

  test('surfaces FDv1 fallback as terminalError', () async {
    final sse = FakeSseClient();
    final init = FDv2StreamingInitializer(base: makeBase(sse));
    final future = init.run();
    await Future<void>.delayed(Duration.zero);

    sse.emitOpen(headers: {'x-ld-fd-fallback': 'true'});

    final result = await future;
    final status = result as StatusResult;
    expect(status.state, equals(SourceState.terminalError));
    expect(status.fdv1Fallback, isTrue);
  });

  test('close before any emission resolves with a shutdown result', () async {
    final sse = FakeSseClient();
    final init = FDv2StreamingInitializer(base: makeBase(sse));
    final future = init.run();
    await Future<void>.delayed(Duration.zero);

    init.close();

    final result = await future;
    expect((result as StatusResult).state, equals(SourceState.shutdown));
    expect(sse.sseClosed, isTrue);
  });

  test('close after run() returns is idempotent', () async {
    final sse = FakeSseClient();
    final init = FDv2StreamingInitializer(base: makeBase(sse));
    final future = init.run();
    await Future<void>.delayed(Duration.zero);

    emitFullPayload(sse);
    await future;

    expect(() => init.close(), returnsNormally);
    expect(() => init.close(), returnsNormally);
  });

  test('close() before run() yields a shutdown result without a subscription',
      () async {
    final sse = FakeSseClient();
    final init = FDv2StreamingInitializer(base: makeBase(sse));

    init.close();
    final result = await init.run();

    expect((result as StatusResult).state, equals(SourceState.shutdown));
  });
}
