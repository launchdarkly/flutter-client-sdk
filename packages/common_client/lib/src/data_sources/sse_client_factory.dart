import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import '../config/defaults/default_config.dart';

/// The details of a streaming connection that the SDK asks an
/// [SSEClientFactory] to create.
///
/// The SDK adds fields to this class over time. A factory that reads only
/// the fields it needs keeps working when a field is added.
final class SSEClientRequest {
  /// Returns the URI for the next connection attempt. The SDK calls this
  /// before the first connection and before every reconnection, because
  /// the query parameters can change between attempts.
  final Uri Function() uriProvider;

  /// The names of the events that the client must emit.
  final Set<String> eventTypes;

  /// The HTTP headers for the connection request.
  final Map<String, String> headers;

  /// The request body, or null when the request has no body.
  final String? body;

  /// The HTTP method for the connection request. A client that does not
  /// report [SSECapability.customMethod] is not used with a method other
  /// than `GET`.
  final SseHttpMethod method;

  /// The logger for the client.
  final EventSourceLogger logger;

  const SSEClientRequest({
    required this.uriProvider,
    required this.eventTypes,
    required this.headers,
    required this.body,
    required this.method,
    required this.logger,
  });
}

/// Creates the [SSEClient] that the SDK uses for streaming.
///
/// The SDK calls the factory once for each streaming connection it needs.
/// The SDK closes the client it receives when it stops streaming.
///
/// The SDK reads [SSEClient.hasCapability] on the returned client:
/// - Without [SSECapability.customMethod], the SDK logs a warning and
///   streams with `GET`, even when `POST` or `REPORT` is configured.
/// - Without [SSECapability.httpErrors], the SDK does not expect an
///   unrecoverable HTTP error on the stream, so every failure is retried.
///
/// On web, the SDK removes the application tags header from the request,
/// because the CORS allow-list of the streaming service does not include it.
typedef SSEClientFactory = SSEClient Function(SSEClientRequest request);

/// Creates the default [SSEClient] for the platform.
SSEClient defaultSseClientFactory(SSEClientRequest request) {
  return SSEClient(request.uriProvider(), request.eventTypes,
      headers: request.headers,
      body: request.body,
      httpMethod: request.method,
      logger: request.logger,
      uriProvider: request.uriProvider);
}

const String _tagsHeader = 'x-launchdarkly-tags';

/// Returns the headers for a streaming request.
///
/// When the application supplied its own client ([customFactory]) on a
/// platform where the service rejects the tags header, the tags header is
/// removed. The default client on that platform sends no headers.
Map<String, String> streamingRequestHeaders(HttpProperties httpProperties,
    {required bool customFactory}) {
  final headers = httpProperties.baseHeaders;
  if (!customFactory ||
      DefaultConfig.dataSourceConfig.streamingTagsHeaderSupported) {
    return headers;
  }
  return {
    for (final entry in headers.entries)
      if (entry.key.toLowerCase() != _tagsHeader) entry.key: entry.value,
  };
}
