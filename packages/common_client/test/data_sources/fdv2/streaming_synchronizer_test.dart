import 'dart:async';
import 'dart:convert';

import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_base.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_synchronizer.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

class FakeSseClient implements SSEClient {
  final StreamController<Event> _controller = StreamController<Event>();
  bool _closed = false;

  bool get sseClosed => _closed;

  void emitMessage(String type, String data) {
    _controller.add(MessageEvent(type, data, null));
  }

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
  test('forwards results from the underlying base', () async {
    final sse = FakeSseClient();
    final sync = FDv2StreamingSynchronizer(base: makeBase(sse));
    final emissions = <FDv2SourceResult>[];
    final sub = sync.results.listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    emitFullPayload(sse, state: 'sel-1');
    emitFullPayload(sse, state: 'sel-2');
    await Future<void>.delayed(Duration.zero);

    expect(emissions, hasLength(2));
    expect((emissions[0] as ChangeSetResult).payload.selector.state,
        equals('sel-1'));
    expect((emissions[1] as ChangeSetResult).payload.selector.state,
        equals('sel-2'));

    await sub.cancel();
  });

  test('close forwards to the base, emitting shutdown', () async {
    final sse = FakeSseClient();
    final sync = FDv2StreamingSynchronizer(base: makeBase(sse));
    final emissions = <FDv2SourceResult>[];
    final done = Completer<void>();
    sync.results.listen(emissions.add, onDone: done.complete);
    await Future<void>.delayed(Duration.zero);

    sync.close();
    await done.future;

    expect(
        (emissions.last as StatusResult).state, equals(SourceState.shutdown));
    expect(sse.sseClosed, isTrue);
  });
}
