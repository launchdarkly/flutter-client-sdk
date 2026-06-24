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
///   connection desire changes.
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
