// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:collection';
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
  test('Test connected emits OpenEvent without headers when entered', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final eventController = StreamController<Event>.broadcast();
    final dataController = StreamController<List<int>>.broadcast();
    final mockClient = MockClient();

    final svo = TestUtils.makeMockStateValues(
        eventTypes: {'put'},
        transitionSink: transitionController,
        eventSink: eventController.sink,
        clientFactory: () => mockClient);

    // connectHeaders is null, so OpenEvent should have no headers
    svo.connectHeaders = null;

    expectLater(transitionController.stream, emitsInOrder([StateConnected]));
    expectLater(eventController.stream, emitsInOrder([OpenEvent()]));

    StateConnected.run(svo, mockClient, dataController.stream);
  });

  test('Test connected emits OpenEvent with headers when entered', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final eventController = StreamController<Event>.broadcast();
    final dataController = StreamController<List<int>>.broadcast();
    final mockClient = MockClient();

    final svo = TestUtils.makeMockStateValues(
        eventTypes: {'put'},
        transitionSink: transitionController,
        eventSink: eventController.sink,
        clientFactory: () => mockClient);

    // Set connectHeaders to simulate headers received from connection
    svo.connectHeaders = {
      'x-custom-header': 'custom-value',
      'content-type': 'text/event-stream'
    };

    final expectedOpenEvent =
        OpenEvent(headers: UnmodifiableMapView(svo.connectHeaders!));

    expectLater(transitionController.stream, emitsInOrder([StateConnected]));
    expectLater(eventController.stream, emitsInOrder([expectedOpenEvent]));

    StateConnected.run(svo, mockClient, dataController.stream);
  });

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
        emitsInOrder([OpenEvent(), MessageEvent('put', 'helloworld', '')]));
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

  test('Test OpenEvent is emitted before MessageEvents in order', () async {
    final transitionController = StreamController<dynamic>.broadcast();
    final eventController = StreamController<Event>.broadcast();
    final dataController = StreamController<List<int>>.broadcast();
    final mockClient = MockClient();

    final svo = TestUtils.makeMockStateValues(
        eventTypes: {'put', 'patch'},
        transitionSink: transitionController,
        eventSink: eventController.sink,
        clientFactory: () => mockClient);

    // Set connectHeaders to simulate headers received from connection
    svo.connectHeaders = {'x-request-id': 'abc123', 'server': 'nginx/1.18.0'};

    final expectedOpenEvent =
        OpenEvent(headers: UnmodifiableMapView(svo.connectHeaders!));

    // Verify that OpenEvent comes first, followed by MessageEvents in order
    expectLater(transitionController.stream, emitsInOrder([StateConnected]));
    expectLater(
        eventController.stream,
        emitsInOrder([
          expectedOpenEvent,
          MessageEvent('put', 'first-message', '1'),
          MessageEvent('patch', 'second-message', '2')
        ]));

    StateConnected.run(svo, mockClient, dataController.stream);

    // Send multiple events to verify ordering
    dataController.add(utf8.encode('id:1\nevent:put\ndata:first-message\n\n'));
    dataController
        .add(utf8.encode('id:2\nevent:patch\ndata:second-message\n\n'));
  });
}
