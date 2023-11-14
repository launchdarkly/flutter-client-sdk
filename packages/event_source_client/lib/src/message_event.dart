/// Represents a message that came across the SSE stream.
class MessageEvent {
  /// The type of the message.
  final String type;

  /// The data sent in the message.
  final String data;

  /// An optional message id that was provided.
  final String? id;

  /// Creates the message with the provided values.
  MessageEvent(this.type, this.data, this.id);

  @override
  String toString() {
    return '{type:$type,data:$data,id:$id}';
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
