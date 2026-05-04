/// Computes how long to wait before the next poll, given when the SDK
/// last received a fresh response and the configured polling interval.
///
/// Returns the time remaining in the interval relative to [freshness].
/// If [freshness] is null (no successful poll yet) returns the full interval.
/// If [freshness] is older than the interval (we're overdue), returns zero.
///
/// Caps the returned delay at [interval] so a freshness timestamp from
/// the future (clock skew, manually adjusted system time) cannot push
/// the next poll arbitrarily far out.
Duration calculatePollDelay({
  required DateTime now,
  required Duration interval,
  DateTime? freshness,
}) {
  if (freshness == null) {
    return interval;
  }
  final elapsed = now.difference(freshness);
  if (elapsed.isNegative) {
    return interval;
  }
  if (elapsed >= interval) {
    return Duration.zero;
  }
  return interval - elapsed;
}
