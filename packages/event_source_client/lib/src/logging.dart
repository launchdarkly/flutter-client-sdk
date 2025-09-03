enum LogLevel {
  debug,
  info,
  warn,
  error,
  none,
}

/// Simple logging interface for the event source client
abstract interface class EventSourceLogger {
  /// Log a debug message
  void debug(String message);

  /// Log an info message
  void info(String message);

  /// Log a warning message
  void warn(String message);

  /// Log an error message
  void error(String message);
}

/// No-op logger implementation that does nothing
class NoOpLogger implements EventSourceLogger {
  const NoOpLogger();

  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warn(String message) {}

  @override
  void error(String message) {}
}

/// Simple print-based logger for basic logging
class PrintLogger implements EventSourceLogger {
  final LogLevel _level;
  final String _tag;

  const PrintLogger(
      {LogLevel level = LogLevel.info, String tag = 'LaunchDarkly EventSource'})
      : _level = level,
        _tag = tag;

  @override
  void debug(String message) {
    if (_level == LogLevel.debug) {
      print('[$_tag DEBUG] $message');
    }
  }

  @override
  void info(String message) {
    if (_level == LogLevel.debug || _level == LogLevel.info) {
      print('[$_tag INFO] $message');
    }
  }

  @override
  void warn(String message) {
    if (_level == LogLevel.debug ||
        _level == LogLevel.info ||
        _level == LogLevel.warn) {
      print('[$_tag WARN] $message');
    }
  }

  @override
  void error(String message) {
    if (_level == LogLevel.debug ||
        _level == LogLevel.info ||
        _level == LogLevel.warn ||
        _level == LogLevel.error) {
      print('[$_tag ERROR] $message');
    }
  }
}
