/// FDv2 endpoint paths.
///
/// These paths are uniform across mobile and browser SDKs; FDv2 does
/// not distinguish between platforms at the endpoint level.
abstract final class FDv2Endpoints {
  /// Polling path used for POST requests. The evaluation context is
  /// sent in the request body.
  static const String polling = '/sdk/poll/eval';

  /// Streaming path used for POST requests. The evaluation context is
  /// sent in the request body.
  static const String streaming = '/sdk/stream/eval';

  /// Builds the polling GET path with the base64url-encoded context
  /// embedded in the URL path.
  static String pollingGet(String encodedContext) => '$polling/$encodedContext';

  /// Builds the streaming GET path with the base64url-encoded context
  /// embedded in the URL path.
  static String streamingGet(String encodedContext) =>
      '$streaming/$encodedContext';
}
