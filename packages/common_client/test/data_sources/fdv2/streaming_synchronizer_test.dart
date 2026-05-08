import 'dart:async';
import 'dart:convert';

import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_base.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_synchronizer.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

TestSseClient makeSse() => SSEClient.testClient(Uri.parse('/test'), const {});

void emitMessage(TestSseClient sse, String type, String data) {
  sse.emitEvent(MessageEvent(type, data, null));
}

void emitFullPayload(TestSseClient sse, {String state = 'sel-1'}) {
  emitMessage(
    sse,
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
  emitMessage(
    sse,
    'put-object',
    jsonEncode({
      'kind': 'flag-eval',
      'key': 'k',
      'version': 1,
      'object': {'value': true, 'version': 1, 'variation': 0},
    }),
  );
  emitMessage(
    sse,
    'payload-transferred',
    jsonEncode({'state': state, 'version': 1}),
  );
}

FDv2StreamingBase makeBase(TestSseClient sse) => FDv2StreamingBase(
      sseClient: sse,
      pingHandler: () async =>
          FDv2SourceResults.interrupted(message: 'no ping'),
      logger: LDLogger(level: LDLogLevel.error),
    );

void main() {
  test('forwards results from the underlying base', () async {
    final sse = makeSse();
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
    final sse = makeSse();
    final sync = FDv2StreamingSynchronizer(base: makeBase(sse));
    final emissions = <FDv2SourceResult>[];
    final done = Completer<void>();
    sync.results.listen(emissions.add, onDone: done.complete);
    await Future<void>.delayed(Duration.zero);

    sync.close();
    await done.future;

    expect(
        (emissions.last as StatusResult).state, equals(SourceState.shutdown));
    expect(sse.isClosed, isTrue);
  });

  test('close() is safe to call from an onData listener reacting to goodbye',
      () async {
    // The Synchronizer interface contract documents close() as
    // idempotent. A close() call from inside the listener's onData
    // when reacting to a goodbye must not throw.
    final sse = makeSse();
    final sync = FDv2StreamingSynchronizer(base: makeBase(sse));
    Object? caught;
    runZonedGuarded(() {
      sync.results.listen((event) {
        if (event is StatusResult && event.state == SourceState.goodbye) {
          sync.close();
        }
      });
    }, (err, _) => caught = err);

    await Future<void>.delayed(Duration.zero);
    emitMessage(
      sse,
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
    emitMessage(sse, 'goodbye', jsonEncode({'reason': 'maintenance'}));
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(caught, isNull,
        reason: 'sync.close() from onData on goodbye must not throw');
    expect(sse.isClosed, isTrue);
  });
}
