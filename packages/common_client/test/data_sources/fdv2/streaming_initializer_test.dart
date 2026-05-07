import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_base.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_initializer.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

TestSseClient makeSse() => SSEClient.testClient(Uri.parse('/test'), const {});

void emitMessage(TestSseClient sse, String type, String data) {
  sse.emitEvent(MessageEvent(type, data, null));
}

void emitOpen(TestSseClient sse, {Map<String, String>? headers}) {
  sse.emitEvent(OpenEvent(
      headers: headers == null ? null : UnmodifiableMapView(headers)));
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
  test('returns the first ChangeSetResult and tears the connection down',
      () async {
    final sse = makeSse();
    final init = FDv2StreamingInitializer(base: makeBase(sse));

    final future = init.run();
    // Yield once so run subscribes to the base.
    await Future<void>.delayed(Duration.zero);

    emitFullPayload(sse, state: 'sel-init');
    final result = await future;

    expect(result, isA<ChangeSetResult>());
    expect(
        (result as ChangeSetResult).payload.selector.state, equals('sel-init'));
    expect(sse.isClosed, isTrue);
  });

  test('surfaces a goodbye result as the first emission', () async {
    final sse = makeSse();
    final init = FDv2StreamingInitializer(base: makeBase(sse));
    final future = init.run();
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

    final result = await future;
    expect((result as StatusResult).state, equals(SourceState.goodbye));
    expect(sse.isClosed, isTrue);
  });

  test('surfaces FDv1 fallback as terminalError', () async {
    final sse = makeSse();
    final init = FDv2StreamingInitializer(base: makeBase(sse));
    final future = init.run();
    await Future<void>.delayed(Duration.zero);

    emitOpen(sse, headers: {'x-ld-fd-fallback': 'true'});

    final result = await future;
    final status = result as StatusResult;
    expect(status.state, equals(SourceState.terminalError));
    expect(status.fdv1Fallback, isTrue);
  });

  test('close before any emission resolves with a shutdown result', () async {
    final sse = makeSse();
    final init = FDv2StreamingInitializer(base: makeBase(sse));
    final future = init.run();
    await Future<void>.delayed(Duration.zero);

    init.close();

    final result = await future;
    expect((result as StatusResult).state, equals(SourceState.shutdown));
    expect(sse.isClosed, isTrue);
  });

  test('close after run() returns is idempotent', () async {
    final sse = makeSse();
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
    final sse = makeSse();
    final init = FDv2StreamingInitializer(base: makeBase(sse));

    init.close();
    final result = await init.run();

    expect((result as StatusResult).state, equals(SourceState.shutdown));
  });
}
