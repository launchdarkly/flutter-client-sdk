import 'dart:async';

import 'package:launchdarkly_event_source_client/src/state_connecting.dart';
import 'package:launchdarkly_event_source_client/src/state_idle.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('Test idle to connecting when subscribed', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final connectionController = StreamController<bool>.broadcast();

    final svo = TestUtils.makeMockStateValues(
        connectionDesired: connectionController.stream,
        transitionSink: transitionController);

    expectLater(transitionController.stream,
        emitsInOrder([StateIdle, StateConnecting]));
    StateIdle.run(svo);
    connectionController.add(true);
  });

  test('Test idle cleans up when control stream closed', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final connectionController = StreamController<bool>.broadcast();

    final svo = TestUtils.makeMockStateValues(
        connectionDesired: connectionController.stream,
        transitionSink: transitionController);

    // should not block for any duration of time
    connectionController.close();
    expectLater(transitionController.stream, emitsInOrder([StateIdle]));
    await StateIdle.run(svo).timeout(Duration(seconds: 1));
  });
}
