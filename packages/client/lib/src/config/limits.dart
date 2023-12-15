Duration durationWithMin(
    Duration defaultDuration, Duration? desired, Duration min) {
  if (desired == null) {
    return defaultDuration;
  }
  if (desired.inMilliseconds < min.inMilliseconds) {
    return min;
  }
  return desired;
}
