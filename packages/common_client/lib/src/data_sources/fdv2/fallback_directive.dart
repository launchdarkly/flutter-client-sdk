import 'dart:math';

/// The longest server-supplied fallback TTL that is honored, and the
/// (jittered) default used when the server gives no usable TTL.
const Duration maxFallbackTtl = Duration(hours: 1);

/// The FDv1 fallback directive parsed from a connection's response
/// headers. Its presence means the server asked the SDK to fall back;
/// [ttl] is the server-supplied time to remain on the fallback before
/// retrying FDv2, unvalidated (null when absent or not an integer). See
/// [resolveFallbackTtl].
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

/// Returns how long to remain on the fallback before retrying FDv2. A
/// server-supplied [ttl] in (0, [maxFallbackTtl]] is used as-is. Anything
/// else (absent, zero, negative, or too long) uses [maxFallbackTtl] minus
/// a uniformly random jitter of up to half of it, so SDKs that fell back
/// together do not all retry at once. Fallback is never indefinite.
Duration resolveFallbackTtl(Duration? ttl, [Random? random]) {
  if (ttl case final valid?
      when valid > Duration.zero && valid <= maxFallbackTtl) {
    return valid;
  }
  final maxJitterSeconds = maxFallbackTtl.inSeconds ~/ 2;
  final jitterSeconds = (random ?? Random()).nextInt(maxJitterSeconds + 1);
  return maxFallbackTtl - Duration(seconds: jitterSeconds);
}
