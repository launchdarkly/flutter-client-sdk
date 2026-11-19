/// Reported on the event stream when the server responds with a non-200
/// HTTP status. Carries the status code and the response headers, which
/// may hold service directives (e.g. protocol fallback instructions) even
/// on error responses.
///
/// [recoverable] tells whether a retry is likely to help:
/// - `true`: the status is likely transient. With automatic reconnect on,
///   the client has scheduled a reconnect with backoff. The subscription
///   stays open; the error is an advisory the consumer may act on (or ignore
///   and let the retry run).
/// - `false`: a retry is unlikely to help. The client stops reconnecting
///   until connection desire changes.
///
/// A client made with `autoReconnect: false` stops after any error status.
///
/// Only produced by implementations whose transport can observe HTTP
/// responses. The browser's native `EventSource` cannot, so on `html`
/// platforms this error is never reported.
final class SseHttpError implements Exception {
  /// The HTTP status code of the response.
  final int statusCode;

  /// The response headers, lower-cased keys as provided by the transport.
  final Map<String, String> headers;

  /// Whether a retry is likely to help.
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

/// Reported on the event stream when a connection fails for a reason other
/// than an HTTP error status. Examples are a timeout, a transport failure,
/// a wrong content type, and a stream that the server ends.
///
/// Only a client made with `autoReconnect: false` reports this error.
final class SseConnectionError implements Exception {
  /// A fixed description of the failure. It never contains the request URL,
  /// so it is safe to log.
  final String message;

  const SseConnectionError(this.message);

  @override
  String toString() => 'SseConnectionError($message)';
}
