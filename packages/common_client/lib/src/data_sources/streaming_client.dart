import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import '../config/defaults/default_config.dart';

/// Builds the SSE client for a streaming connection.
///
/// The type has the shape of the [SSEClient] constructors, so [SSEClient.new]
/// and [SSEClient.http] are builders. Tests inject a fake.
typedef SseClientBuilder = SSEClient Function(Uri uri, Set<String> eventTypes,
    {required Map<String, String> headers,
    required String? body,
    required SseHttpMethod httpMethod,
    required EventSourceLogger logger,
    Uri Function()? uriProvider});

/// Returns the builder for the configuration.
///
/// With [useHttpStreamingOnWeb], the SDK streams with the HTTP-based client
/// on every platform. Without it, the SDK uses the default client for the
/// platform. On platforms other than web, both are the HTTP-based client.
SseClientBuilder sseClientBuilderFor({required bool useHttpStreamingOnWeb}) =>
    useHttpStreamingOnWeb ? SSEClient.http : SSEClient.new;

/// Whether the streaming client can send a POST or REPORT request with a
/// body. The browser `EventSource` cannot. The HTTP-based client can.
bool streamingCustomMethodSupported({required bool useHttpStreamingOnWeb}) =>
    useHttpStreamingOnWeb ||
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
