import 'dart:collection';

final class Event {}

/// Represents a message that came across the SSE stream.
final class MessageEvent implements Event {
  /// The type of the message.
  final String type;

  /// The data sent in the message.
  final String data;

  /// An optional message id that was provided.
  final String? id;

  /// Creates the message with the provided values.
  const MessageEvent(this.type, this.data, this.id);

  @override
  String toString() {
    return 'MessageEvent{type:$type,data:$data,id:$id}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          data == other.data &&
          id == other.id;

  @override
  int get hashCode => type.hashCode ^ data.hashCode ^ id.hashCode;
}

/// Event emitted when the SSE client connects.
final class ConnectedEvent implements Event {
  /// Any headers associated with the connection.
  final UnmodifiableMapView<String, String>? headers;

  /// Create a connected event with the specified headers.
  const ConnectedEvent({this.headers});

  @override
  String toString() {
    return 'ConnectedEvent{headers:$headers}';
  }

  bool _compareHeaders(UnmodifiableMapView<String, String>? otherHeaders) {
    if (headers == null && otherHeaders == null) {
      return true;
    }
    if (headers != null && otherHeaders == null) {
      return false;
    }
    if (headers == null && otherHeaders != null) {
      return false;
    }
    var self = headers!;
    var other = otherHeaders!;
    if (self.length != other.length) {
      return false;
    }
    for (var pair in self.entries) {
      if (!other.containsKey(pair.key)) {
        return false;
      }
      if (pair.value != other[pair.key]) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConnectedEvent && _compareHeaders(other.headers);
  }

  @override
  int get hashCode => headers != null
      ? Object.hashAllUnordered(
          headers!.entries.map((item) => Object.hash(item.key, item.value)))
      : null.hashCode;
}

bool isMessageEvent(Event event) {
  {
    switch (event) {
      case MessageEvent():
        return true;
      default:
        return false;
    }
  }
}
