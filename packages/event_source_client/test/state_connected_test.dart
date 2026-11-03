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

// Mutable state for one run of the connected state against an open response
// stream.
class _Harness {
  final client = MockClient();
  final desired = StreamController<bool>.broadcast();
  final reset = StreamController<void>.broadcast();
  final transitions = <dynamic>[];
  final events = <Event>[];
  var cancelled = false;
  late final StreamController<List<int>> data;

  _Harness({FutureOr<void> Function()? onCancel}) {
    data = StreamController<List<int>>(onCancel: () {
      cancelled = true;
      return onCancel?.call();
    });
  }
}

// Accepts the open event and throws for a message event, like a closed sink.
class _ThrowOnMessageSink implements EventSink<Event> {
  @override
  void add(Event event) {
    if (event is MessageEvent) {
      throw StateError('The sink is closed.');
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  void close() {}
}

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

  group('when the connection must end while the response stream is open', () {
    // Runs the connected state against an open response stream, then calls
    // [stop]. The read timeout is long, because a short one would cancel the
    // stream by itself.
    Future<_Harness> runAndStop(void Function(_Harness h) stop,
        {FutureOr<void> Function()? onCancel,
        EventSink<Event>? eventSink}) async {
      final h = _Harness(onCancel: onCancel);
      final transitions = StreamController<dynamic>.broadcast();
      final events = StreamController<Event>.broadcast();
      transitions.stream.listen(h.transitions.add);
      events.stream.listen(h.events.add);

      final svo = TestUtils.makeMockStateValues(
          eventTypes: {'put'},
          connectionDesired: h.desired.stream,
          resetStream: h.reset.stream,
          transitionSink: transitions,
          eventSink: eventSink ?? events.sink,
          readTimeout: const Duration(minutes: 5));

      // Closing the control streams ends the next state. That state can still
      // write one transition, so the sinks close after the queue is empty.
      addTearDown(() async {
        await h.desired.close();
        await h.reset.close();
        await pumpEventQueue();
        await transitions.close();
        await events.close();
        // The response stream may have a cancel that never completes.
        unawaited(h.data.close());
      });

      final running = StateConnected.run(svo, h.client, h.data.stream);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      stop(h);
      await running;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return h;
    }

    void notDesired(_Harness h) => h.desired.add(false);
    void resetRequested(_Harness h) => h.reset.add(null);

    for (final (name, stop, next) in [
      ('connection is not desired', notDesired, StateIdle),
      ('reset is requested', resetRequested, StateBackoff),
    ]) {
      test(
          'it cancels the response stream and closes the client when the $name',
          () async {
        final h = await runAndStop(stop);

        // Closing the client alone does not end a response body on web.
        expect(h.cancelled, isTrue);
        verify(() => h.client.close()).called(1);
        expect(h.transitions, [StateConnected, next]);
      });

      test('it emits no event that arrives right after the $name', () async {
        final h = await runAndStop((h) {
          stop(h);
          h.data.add(utf8.encode('event:put\ndata:late\n\n'));
        });

        expect(h.events, [OpenEvent()]);
      });
    }

    test(
        'it still moves to the next state when cancelling the response '
        'stream throws', () async {
      final h =
          await runAndStop(notDesired, onCancel: () => throw StateError('x'));

      expect(h.cancelled, isTrue);
      expect(h.transitions, [StateConnected, StateIdle]);
    });

    test(
        'it still moves to the next state when cancelling the response '
        'stream never completes', () async {
      final h = await runAndStop(notDesired,
          onCancel: () => Completer<void>().future);

      expect(h.cancelled, isTrue);
      expect(h.transitions, [StateConnected, StateIdle]);
    });

    test('it cancels the response stream when handling an event throws',
        () async {
      final h = await runAndStop(
          (h) => h.data.add(utf8.encode('event:put\ndata:x\n\n')),
          eventSink: _ThrowOnMessageSink());

      expect(h.cancelled, isTrue);
      expect(h.transitions, [StateConnected, StateBackoff]);
    });
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
