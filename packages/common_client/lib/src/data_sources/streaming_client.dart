import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import '../config/defaults/default_config.dart';

/// Builds the SSE client for a streaming connection.
///
/// The type has the shape of the [SSEClient] constructors, so [SSEClient.new]
/// and [SSEClient.http] are builders. The SDK calls the builder once for each
/// streaming connection it needs, and closes the client when it stops
/// streaming.
typedef SseClientBuilder = SSEClient Function(Uri uri, Set<String> eventTypes,
    {required Map<String, String> headers,
    required String? body,
    required SseHttpMethod httpMethod,
    required EventSourceLogger logger,
    Uri Function()? uriProvider});

/// Whether the streaming client can send a POST or REPORT request with a
/// body.
///
/// The SDK treats a supplied [eventSource] as able to send a body. The
/// default client, [SSEClient.new], has the capability of the platform. This
/// is true when it is passed as the builder and when [eventSource] is null.
/// On web, the default client is the browser `EventSource`, which cannot
/// send a body. The SDK cannot recognize a function that wraps the default
/// client.
bool streamingCustomMethodSupported({required SseClientBuilder? eventSource}) =>
    (eventSource != null && !identical(eventSource, SSEClient.new)) ||
    DefaultConfig.dataSourceConfig.streamingPostSupported;

const String _tagsHeader = 'x-launchdarkly-tags';

/// Returns the headers for a streaming request.
///
/// On web, the function removes the application tags header. The CORS
/// allow-list of the streaming service does not include it, so a browser
/// blocks a request that sends it.
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
