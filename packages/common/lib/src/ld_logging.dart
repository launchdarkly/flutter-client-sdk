/// Logging levels that can be used with [LDLogger].
/// Set the log level to one of these values when constructing a [LDLogger]
/// to control level of log messages are enabled.
/// Going from lowest importance (and most verbose) to most importance, the
/// levels are: [LDLogLevel.debug], [LDLogLevel.info], [LDLogLevel.warn],
/// and [LDLogLevel.error].
/// You can also specify `'none'` instead to disable all logging.
enum LDLogLevel {
  /// This level is for very detailed and verbose messages that are rarely
  /// useful except in diagnosing an unusual problem. This level is mostly
  /// used by SDK developers.
  debug(0),

  /// This level is for informational messages that are logged during normal
  /// operation.
  info(1),

  /// This level is for messages about unexpected conditions that may be worth
  /// noting, but that do not necessarily prevent things from working.
  warn(2),

  /// This level is for errors that should not happen during normal operation
  /// and should be investigated.
  error(3),

  /// This level is not used for output; setting the minimum enabled level to
  /// [LDLogLevel.none] disables all output.
  none(4);

  final num _value;

  const LDLogLevel(this._value);

  operator <(LDLogLevel other) {
    return _value < other._value;
  }

  operator <=(LDLogLevel other) {
    return _value <= other._value;
  }

  operator >(LDLogLevel other) {
    return _value > other._value;
  }

  operator >=(LDLogLevel other) {
    return _value >= other._value;
  }
}

/// Represents a log entry from [LDLogger]. It can be used with an
/// [LDLogAdapter] to control logging output from the SDK.
final class LDLogRecord {
  final LDLogLevel level;
  final String message;
  final DateTime time;
  final String logTag;

  const LDLogRecord(
      {required this.level,
      required this.message,
      required this.time,
      required this.logTag});
}

/// Interface used by log printers for use with the SDK.
/// A custom implementation can be used to adapt the SDK log output to a logging
/// framework of your choice.
///
/// For instance an adapter for [logger](https://pub.dev/packages/logger) may
/// look like the following.
/// ```dart
/// class MyLoggerAdapter implements LDLogAdapter {
///   final Logger _logger;
///   MyLoggerAdapter(this._logger);
///
///   log(LDLogRecord record) {
///     final formatted ='[${record.logTag}] ${record.level} ${record.time}: ${record.message}';
///     switch(record.level) {
///       case LDLogLevel.none:
///         break;
///       case LDLogLevel.debug:
///         _logger.d(formatted);
///         break;
///       case LDLogLevel.info:
///         _logger.i(formatted);
///         break;
///       case LDLogLevel.warn:
///         _logger.w(formatted);
///         break;
///       case LDLogLevel.error:
///         _logger.e(formatted);
///     }
///   }
/// }
/// ```
abstract interface class LDLogAdapter {
  /// Handle a log record emitted by the logger. This can be used to control
  /// the output of SDK log messages.
  log(LDLogRecord record);
}

/// Basic log printer which will output all messages using
/// [print].
class LDBasicLogPrinter implements LDLogAdapter {
  const LDBasicLogPrinter();

  @override
  log(LDLogRecord record) {
    print(
        '[${record.logTag} ${record.level.name} ${record.time.toIso8601String()}] ${record.message}');
  }
}

/// Logging implementation used by the SDK. A default constructed logger
/// will enable the [LDLogLevel.info] level and will output messages using
/// the [LDBasicLogPrinter].
final class LDLogger {
  late final LDLogAdapter _adapter;

  final LDLogLevel level;
  final String logTag;

  /// Construct a logger.
  ///
  /// The [adapter] can be used to control the destination
  /// of log messages. For instance to adapt them to your desired logging
  /// package. For an example read [LDLogAdapter].
  ///
  /// [level] controls the level of logging enabled. If you want to control
  /// the log level using your logging framework, then you can set the level
  /// to [LDLogLevel.debug] and all messages will be sent to your [LDLogAdapter].
  ///
  /// The logger can be configured with a [logTag] and it will default to
  /// "LaunchDarkly". Additional loggers can be created using
  /// [LDLogger.subLogger] and they will have an extended log tag.
  LDLogger(
      {adapter = const LDBasicLogPrinter(),
      this.level = LDLogLevel.info,
      this.logTag = 'LaunchDarkly'}) {
    _adapter = adapter;
  }

  /// Create a sub-logger with an additional tag. The tag will be appended
  /// to the base tag. For instance `logger.subLogger("Streaming")`, when called
  /// on a default logger instance, would result in a tag of
  /// `LaunchDarkly.Streaming`. This is primarily intended to structure the
  /// log messages emitted by the SDK.
  LDLogger subLogger(String subTag) {
    return LDLogger(adapter: _adapter, level: level, logTag: '$logTag.$subTag');
  }

  /// Check if the specified log level is enabled.
  bool isLevelEnabled(LDLogLevel toCheck) {
    return toCheck >= level;
  }

  _log(LDLogLevel level, String message) {
    if (isLevelEnabled(level)) {
      _adapter.log(LDLogRecord(
          level: level,
          message: message,
          time: DateTime.now(),
          logTag: logTag));
    }
  }

  /// Log a debug message. The message will not be sent to the [LDLogAdapter]
  /// if the logging level is not enabled.
  debug(String message) => _log(LDLogLevel.debug, message);

  /// Log an informative message. The message will not be sent to the
  /// [LDLogAdapter] if the logging level is not enabled.
  info(String message) => _log(LDLogLevel.info, message);

  /// Log a warning message. The message will not be sent to the [LDLogAdapter]
  /// if the logging level is not enabled.
  warn(String message) => _log(LDLogLevel.warn, message);

  /// Log an error message. The message will not be sent to the [LDLogAdapter]
  /// if the logging level is not enabled.
  error(String message) => _log(LDLogLevel.error, message);
}
