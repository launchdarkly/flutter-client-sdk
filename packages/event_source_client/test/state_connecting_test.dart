import 'dart:async';

import 'package:launchdarkly_event_source_client/src/http_consts.dart';
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

  test('Test connecting to backoff on recoverable error', () async {
    final transitionController = StreamController<dynamic>.broadcast();

    final svo = TestUtils.makeMockStateValues(
        transitionSink: transitionController,
        clientFactory: () => TestUtils.makeMockHttpClient(
            httpStatusCode: HttpStatusCodes.tooManyRequestsStatus));

    expectLater(transitionController.stream,
        emitsInOrder([StateConnecting, StateBackoff]));
    await StateConnecting.run(svo);
  });

  test('Test connecting to idle on unrecoverable error', () async {
    final transitionController = StreamController<dynamic>.broadcast();

    final svo = TestUtils.makeMockStateValues(
        transitionSink: transitionController,
        clientFactory: () => TestUtils.makeMockHttpClient(httpStatusCode: 404));

    expectLater(transitionController.stream,
        emitsInOrder([StateConnecting, StateIdle]));
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
