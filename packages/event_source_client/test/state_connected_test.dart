// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:launchdarkly_event_source_client/src/events.dart';
import 'package:launchdarkly_event_source_client/src/state_backoff.dart';
import 'package:launchdarkly_event_source_client/src/state_connected.dart';
import 'package:launchdarkly_event_source_client/src/state_idle.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

class MockClient extends Mock implements Client {}

void main() {
  test('Test connected emits events', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final eventController = StreamController<Event>.broadcast();
    final dataController = StreamController<List<int>>.broadcast();
    final mockClient =
        MockClient(); // this mock client doesn't do anything in this test case

    // blocking client to stop us from going to connected state
    final svo = TestUtils.makeMockStateValues(
        eventTypes: {'put'},
        transitionSink: transitionController,
        eventSink: eventController.sink,
        clientFactory: () => mockClient);

    expectLater(transitionController.stream, emitsInOrder([StateConnected]));
    expectLater(eventController.stream,
        emitsInOrder([MessageEvent('put', 'helloworld', '')]));
    StateConnected.run(svo, mockClient, dataController.stream);
    dataController.add(utf8.encode('event:put\ndata:helloworld\n\n'));
  });

  test('Test connected cleans up when control stream closed', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final connectionController = StreamController<bool>.broadcast();
    final dataController = StreamController<List<int>>.broadcast();
    final mockClient = MockClient(); // exists to verify close is called

    // blocking client to stop us from going to connected state
    final svo = TestUtils.makeMockStateValues(
        connectionDesired: connectionController.stream,
        transitionSink: transitionController,
        clientFactory: () => mockClient);

    // should not block for any duration of time
    connectionController.close();
    expectLater(
        transitionController.stream, emitsInOrder([StateConnected, StateIdle]));
    await StateConnected.run(svo, mockClient, dataController.stream);
    verify(() => mockClient.close()).called(1);
  });

  test('it transitions to backoff when a reset is requested', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final connectionController = StreamController<bool>.broadcast();
    final resetController = StreamController<void>();
    final dataController = StreamController<List<int>>.broadcast();
    final mockClient = MockClient(); // exists to verify close is called

    // blocking client to stop us from going to connected state
    final svo = TestUtils.makeMockStateValues(
      connectionDesired: connectionController.stream,
      transitionSink: transitionController,
      resetStream: resetController.stream.asBroadcastStream(),
      clientFactory: () => mockClient,
    );

    expectLater(transitionController.stream,
        emitsInOrder([StateConnected, StateBackoff]));

    resetController.sink.add(null);
    await StateConnected.run(svo, mockClient, dataController.stream);
  });
}
