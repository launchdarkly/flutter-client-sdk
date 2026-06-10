/// Reported on the event stream when the server responds with an HTTP
/// status code that the client will not retry (anything other than 200,
/// 400, 408, 429, or 5xx). After reporting this error the client stops
/// reconnecting until connection desire changes.
final class UnrecoverableStatusError implements Exception {
  /// The HTTP status code of the response.
  final int statusCode;

  /// The response headers, when available. May carry service directives
  /// (e.g. protocol fallback instructions) even on error responses.
  final Map<String, String> headers;

  const UnrecoverableStatusError(this.statusCode,
      [this.headers = const <String, String>{}]);

  @override
  String toString() => 'UnrecoverableStatusError(statusCode: $statusCode)';
}
