import 'defaults/common_default_config.dart';

final class HttpProperties {
  /// The connection timeout for requests.
  final Duration connectTimeout;

  /// The read timeout for individual requests. This is the time after the
  /// headers are received and the body finishes being read.
  final Duration readTimeout;

  /// The write timeout for individual requests. This is the time to complete
  /// writing the request body.
  final Duration writeTimeout;

  /// Headers that are included in all requests when possible. Not all
  /// connections support headers. Streaming requests on web will not include
  /// any customized headers. Additionally some headers are forbidden on some
  /// platforms and will be omitted on those platforms.
  final Map<String, String> baseHeaders;

  /// Construct an http properties instance.
  ///
  /// The [connectTimeout] is the time between initiating a connection and either
  /// starting to receive a body or writing a body.
  ///
  /// The [readTimeout] is the time after receiving headers until the body
  /// completes being read.
  ///
  /// The [writeTimeout] is the time between starting to write the body
  /// and finishing writing the body.
  ///
  /// [baseHeaders] are headers that will be added to all requests
  /// when possible. Not all connections support including headers.
  HttpProperties(
      {Duration? connectTimeout,
      Duration? readTimeout,
      Duration? writeTimeout,
      Map<String, String> baseHeaders = const {}})
      : baseHeaders = Map.unmodifiable(baseHeaders),
        connectTimeout =
            connectTimeout ?? CommonDefaultConfig.networkConfig.connectTimeout,
        readTimeout =
            readTimeout ?? CommonDefaultConfig.networkConfig.readTimeout,
        writeTimeout =
            writeTimeout ?? CommonDefaultConfig.networkConfig.writeTimeout;

  /// Create an http properties instance based on this instance with
  /// additional headers.
  HttpProperties withHeaders(Map<String, String> additionalHeaders) {
    final combinedHeaders = <String, String>{};
    combinedHeaders.addAll(baseHeaders);
    combinedHeaders.addAll(additionalHeaders);
    return HttpProperties(
        connectTimeout: connectTimeout,
        readTimeout: readTimeout,
        baseHeaders: combinedHeaders,
        writeTimeout: writeTimeout);
  }
}
