import 'dart:async';

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
  ///
  /// With `GET`, the URI carries the evaluation context. Do not log it.
  final Uri Function() uriProvider;

  /// The names of the events that the client must emit.
  final Set<String> eventTypes;

  /// The HTTP headers for the connection request. They carry the SDK
  /// credential. Do not log them.
  final Map<String, String> headers;

  /// The request body, or null when the request has no body. With `POST` or
  /// `REPORT`, the body is the evaluation context.
  final String? body;

  /// The HTTP method for the connection request.
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
/// The SDK calls the factory when it opens a streaming connection. When the
/// configured method is `POST` or `REPORT`, the SDK reads
/// [SSEClient.hasCapability] on the client it receives. Without
/// [SSECapability.customMethod], the SDK logs a warning, closes that client,
/// and calls the factory a second time with a `GET` request. The `GET`
/// request carries the evaluation context in the URI.
///
/// Without [SSECapability.httpErrors], the SDK does not expect an
/// unrecoverable HTTP error on the stream, so every failure is retried.
///
/// The SDK closes the client when it stops streaming.
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

/// Builds the client for a streaming connection.
///
/// [requestFor] builds the request. Its argument says whether the request
/// uses the configured custom method, `POST` or `REPORT`. When
/// [useCustomMethod] is set and the client does not report
/// [SSECapability.customMethod], this logs a warning, closes that client,
/// and builds a `GET` client instead.
///
/// Returns the client and whether it uses the custom method.
(SSEClient, bool) createSseClient({
  required SSEClientFactory? factory,
  required SSEClientRequest Function(bool useCustomMethod) requestFor,
  required bool useCustomMethod,
  required LDLogger logger,
}) {
  final build = factory ?? defaultSseClientFactory;
  final request = requestFor(useCustomMethod);
  final client = build(request);
  if (!useCustomMethod || client.hasCapability(SSECapability.customMethod)) {
    return (client, useCustomMethod);
  }
  logger.warn('The SSE client cannot send ${request.method} requests. '
      'Streaming with GET instead.');
  closeSseClient(client, logger);
  return (build(requestFor(false)), false);
}

/// Closes [client]. A custom client can fail to close. The failure is
/// logged and does not reach the caller.
void closeSseClient(SSEClient client, LDLogger logger) {
  void report(Object err) {
    logger.warn('The SSE client failed to close: $err');
  }

  try {
    unawaited(client.close().catchError(report));
  } catch (err) {
    report(err);
  }
}

const String _tagsHeader = 'x-launchdarkly-tags';

/// Returns the headers for a streaming request.
///
/// On a platform where the streaming service rejects the application tags
/// header, the tags header is removed.
Map<String, String> streamingRequestHeaders(HttpProperties httpProperties) {
  final headers = httpProperties.baseHeaders;
  if (DefaultConfig.dataSourceConfig.streamingTagsHeaderSupported) {
    return headers;
  }
  return Map.unmodifiable({
    for (final entry in headers.entries)
      if (entry.key.toLowerCase() != _tagsHeader) entry.key: entry.value,
  });
}
