import '../launchdarkly_event_source_client.dart';

// Stub client that will be used on unsupported platforms.
SSEClient getSSEClient(
        Uri uri,
        Set<String> eventTypes,
        Map<String, String> headers,
        Duration connectTimeout,
        Duration readTimeout,
        String? body,
        String method,
        EventSourceLogger? logger) =>
    throw UnsupportedError(
        'LaunchDarkly SSE Client is not supported on this platform.');
