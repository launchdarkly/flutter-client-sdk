import 'mode_definition.dart';

/// Built-in [ModeDefinition] values.
abstract final class BuiltInModes {
  BuiltInModes._();

  /// Default foreground poll interval.
  static const Duration _foregroundPollInterval = Duration(seconds: 300);

  /// Default background poll interval.
  static const Duration defaultBackgroundPollInterval = Duration(seconds: 3600);

  /// Streaming: combination of cache and polling initializers, and streaming and fallback polling synchronizer.
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

  /// Background: cache initializer, reduced-rate polling synchronizer
  static const ModeDefinition background = ModeDefinition(
    initializers: [CacheInitializer()],
    synchronizers: [
      PollingSynchronizer(pollInterval: defaultBackgroundPollInterval),
    ],
    fdv1Fallback: Fdv1FallbackConfig(
      pollInterval: defaultBackgroundPollInterval,
    ),
  );
}
