/// FDv2 endpoint paths.
///
/// These paths are uniform across mobile and browser SDKs; FDv2 does
/// not distinguish between platforms at the endpoint level.
abstract final class FDv2Endpoints {
  /// Polling path. Used as-is for POST requests (context sent in the
  /// request body) and as the prefix for GET requests via [pollingGet].
  static const String polling = '/sdk/poll/eval';

  /// Streaming path. Used as-is for POST requests (context sent in the
  /// request body) and as the prefix for GET requests via [streamingGet].
  static const String streaming = '/sdk/stream/eval';

  /// Builds the polling GET path with the base64url-encoded context
  /// embedded in the URL path.
  static String pollingGet(String encodedContext) => '$polling/$encodedContext';

  /// Builds the streaming GET path with the base64url-encoded context
  /// embedded in the URL path.
  static String streamingGet(String encodedContext) =>
      '$streaming/$encodedContext';
}
