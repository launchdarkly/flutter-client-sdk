/// Reported on the event stream when the server responds with a non-200
/// HTTP status. Carries the status code and the response headers, which
/// may hold service directives (e.g. protocol fallback instructions) even
/// on error responses.
///
/// [recoverable] indicates what the client does next:
/// - `true`: the status is one the client retries, so it has scheduled a
///   reconnect with backoff. The subscription stays open; the error is an
///   advisory the consumer may act on (or ignore and let the retry run).
/// - `false`: the client will not retry. It stops reconnecting until
///   connection desire changes. A client made with automatic reconnect
///   turned off always reports `false`.
///
/// Only produced by implementations whose transport can observe HTTP
/// responses. The browser's native `EventSource` cannot, so on `html`
/// platforms this error is never reported.
final class SseHttpError implements Exception {
  /// The HTTP status code of the response.
  final int statusCode;

  /// The response headers, lower-cased keys as provided by the transport.
  final Map<String, String> headers;

  /// Whether the client will retry this connection on its own.
  final bool recoverable;

  const SseHttpError(
    this.statusCode,
    this.headers, {
    required this.recoverable,
  });

  @override
  String toString() =>
      'SseHttpError(statusCode: $statusCode, recoverable: $recoverable)';
}

/// The part of a connection in which an [SseTimeoutError] occurs.
enum SseTimeoutPhase {
  /// The server did not respond within the connect timeout.
  connect,

  /// The connection was silent for longer than the read timeout.
  read,
}

/// Reported on the event stream when a connection times out.
final class SseTimeoutError implements Exception {
  /// The part of the connection that timed out.
  final SseTimeoutPhase phase;

  const SseTimeoutError(this.phase);

  @override
  String toString() => 'SseTimeoutError(phase: ${phase.name})';
}

/// Reported on the event stream when a connection fails below the HTTP
/// level. Examples are a DNS failure, a TLS failure, a connection reset,
/// and a redirect loop.
final class SseTransportError implements Exception {
  /// The error from the transport. Its string form can contain the request
  /// URL, so do not log it directly.
  final Object cause;

  const SseTransportError(this.cause);

  @override
  String toString() => 'SseTransportError(${cause.runtimeType})';
}

/// Reported on the event stream when the server responds with a 200
/// status, but the content type is not `text/event-stream`.
final class SseContentTypeError implements Exception {
  const SseContentTypeError();

  @override
  String toString() => 'SseContentTypeError()';
}

/// Reported on the event stream when the server ends the stream.
final class SseStreamClosedError implements Exception {
  const SseStreamClosedError();

  @override
  String toString() => 'SseStreamClosedError()';
}
