/// The FDv1 fallback directive parsed from a connection's response
/// headers. Its presence means the server asked the SDK to fall back;
/// [ttl] is how long to remain on the fallback before retrying FDv2
/// (null when the server gave no TTL; [Duration.zero] means indefinitely).
final class FallbackDirective {
  final Duration? ttl;
  const FallbackDirective(this.ttl);
}

/// Reads the FDv1 fallback directive from response headers, or null when
/// the `x-ld-fd-fallback` header is not `"true"`. The single place that
/// interprets these headers, shared by the streaming and polling sources.
FallbackDirective? readFallbackDirective(Map<String, String> headers) {
  if (headers['x-ld-fd-fallback']?.toLowerCase() != 'true') {
    return null;
  }
  final raw = headers['x-ld-fd-fallback-ttl'];
  final seconds = raw == null ? null : int.tryParse(raw);
  return FallbackDirective(seconds == null ? null : Duration(seconds: seconds));
}
