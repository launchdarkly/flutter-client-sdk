/// If [value] is null, or <=0, then return the default value.
Duration durationGreaterThanZeroWithDefault(
    Duration? value, Duration defaultValue) {
  if (value == null || value.inMilliseconds <= 0) {
    return defaultValue;
  }
  return value;
}

/// If the [desired] value is null, or less than min, then return the default.
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
