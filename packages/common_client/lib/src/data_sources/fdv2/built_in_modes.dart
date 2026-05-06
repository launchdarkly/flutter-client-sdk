import 'mode_definition.dart';

/// Built-in [ModeDefinition] values.
abstract final class BuiltInModes {
  BuiltInModes._();

  /// Default foreground poll interval.
  static const Duration _foregroundPollInterval = Duration(seconds: 300);

  /// Default background poll interval.
  static const Duration _backgroundPollInterval = Duration(seconds: 3600);

  /// Default streaming mode (mobile foreground / desktop).
  static const ModeDefinition streaming = ModeDefinition(
    initializers: [
      CacheInitializer(),
      PollingInitializer(),
    ],
    synchronizers: [
      StreamingSynchronizer(),
      PollingSynchronizer(),
    ],
    fdv1Fallback: Fdv1FallbackConfig(
      pollInterval: _foregroundPollInterval,
    ),
  );

  /// Polling-only mode.
  static const ModeDefinition polling = ModeDefinition(
    initializers: [CacheInitializer()],
    synchronizers: [PollingSynchronizer()],
    fdv1Fallback: Fdv1FallbackConfig(
      pollInterval: _foregroundPollInterval,
    ),
  );

  /// Offline: cache initializer only; no synchronizers.
  static const ModeDefinition offline = ModeDefinition(
    initializers: [CacheInitializer()],
    synchronizers: [],
  );

  /// Mobile background: cache initializer, reduced-rate polling synchronizer (CSFDV2 §5.2.3).
  static const ModeDefinition background = ModeDefinition(
    initializers: [CacheInitializer()],
    synchronizers: [
      PollingSynchronizer(pollInterval: _backgroundPollInterval),
    ],
    fdv1Fallback: Fdv1FallbackConfig(
      pollInterval: _backgroundPollInterval,
    ),
  );
}
