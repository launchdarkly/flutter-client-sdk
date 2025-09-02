import 'dart:async';
import 'dart:collection';

import '../launchdarkly_event_source_client.dart';

const String _simulatedErrorString =
    'an error has occurred, any potential string may be provided here and it should not be treated as an interface';

/// An SSE client to use for testing.
///
/// Changes may be made to this class without following semantic conventions.
final class TestSseClient implements SSEClient {
  final UnmodifiableMapView<String, String> headers;
  final Duration connectTimeout;
  final Duration readTimeout;
  final String? body;
  final SseHttpMethod httpMethod;
  late final Stream<Event>? _sourceStream;
  StreamSubscription<Event>? _sourceStreamSubscription;

  /// This controller is for the events going to the subscribers of this client.
  late final StreamController<Event> _messageEventsController;

  @override
  Future close() async {
    _messageEventsController.close();
  }

  @override
  void restart() {}

  @override
  Stream<Event> get stream => _messageEventsController.stream;

  /// Emit an event on the stream.
  /// Has no effect if the client has been closed.
  ///
  /// [event] The event to emit.
  void emitEvent(Event event) {
    if (_messageEventsController.isClosed) {
      return;
    }
    _messageEventsController.sink.add(event);
  }

  /// Emit an error event.
  ///
  /// [error] The error to emit. The event source makes no contract about the
  /// type of errors it will emit. If not error is provided, then a default
  /// error will be emitted.
  void emitError({Object? error}) {
    if (_messageEventsController.isClosed) {
      return;
    }
    if (error != null) {
      _messageEventsController.sink.addError(error);
    } else {
      _messageEventsController.sink.addError(Exception(_simulatedErrorString));
    }
  }

  TestSseClient.internal({
    required this.headers,
    required this.connectTimeout,
    required this.readTimeout,
    required this.body,
    required this.httpMethod,
    Stream<Event>? sourceStream,
  }) {
    _sourceStream = sourceStream;
    _messageEventsController = StreamController<Event>.broadcast(
      onListen: () {
        _sourceStreamSubscription = _sourceStream?.listen((event) {
          emitEvent(event);
        });
        _sourceStreamSubscription?.onError((error) {
          emitError();
        });
      },
      onCancel: () {
        _sourceStreamSubscription?.cancel();
        close();
      },
    );
  }
}
