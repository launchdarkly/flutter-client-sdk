/// Per-source endpoint overrides. When fields are null, the client uses
/// the default [ServiceEndpoints] from config.
final class EndpointConfig {
  final Uri? pollingBaseUri;
  final Uri? streamingBaseUri;

  const EndpointConfig({this.pollingBaseUri, this.streamingBaseUri});
}

/// Marker class for separating initializers from other types of source entries.
sealed class InitializerEntry {
  const InitializerEntry();
}

/// Marker class for separating synchronizers from other types of source entries.
sealed class SynchronizerEntry {
  const SynchronizerEntry();
}

/// Initializer that will read data from cache.
final class CacheInitializer extends InitializerEntry {
  const CacheInitializer();
}

/// Initializer that will make fetch data from polling endpoints.
final class PollingInitializer extends InitializerEntry {
  /// Per-source endpoint overrides.
  final EndpointConfig? endpoints;

  /// Whether to use the report method for the source.
  final bool useReport;

  const PollingInitializer({
    this.endpoints,
    this.useReport = false,
  });
}

/// Streaming initializer (e.g. first payload from a stream).
final class StreamingInitializer extends InitializerEntry {
  /// Initial reconnect delay for the streaming source.
  final Duration? initialReconnectDelay;

  /// Per-source endpoint overrides.
  final EndpointConfig? endpoints;

  /// Whether to use the report method for the source.
  final bool useReport;

  const StreamingInitializer({
    this.initialReconnectDelay,
    this.endpoints,
    this.useReport = false,
  });
}

/// Long-lived polling synchronizer; [pollInterval] overrides client default when set.
final class PollingSynchronizer extends SynchronizerEntry {
  /// Minimum polling interval for the synchronizer.
  final Duration? pollInterval;

  /// Per-source endpoint overrides.
  final EndpointConfig? endpoints;

  /// Whether to use the report method for the source.
  final bool useReport;

  const PollingSynchronizer({
    this.pollInterval,
    this.endpoints,
    this.useReport = false,
  });
}

/// Long-lived streaming synchronizer.
final class StreamingSynchronizer extends SynchronizerEntry {
  final Duration? initialReconnectDelay;

  /// Per-source endpoint overrides.
  final EndpointConfig? endpoints;

  /// Whether to use the report method for the source.
  final bool useReport;

  const StreamingSynchronizer({
    this.initialReconnectDelay,
    this.endpoints,
    this.useReport = false,
  });
}

/// Defines the initializers and synchronizers for a FDv2 connection mode.
final class ModeDefinition {
  final List<InitializerEntry> initializers;
  final List<SynchronizerEntry> synchronizers;
  final Fdv1FallbackConfig? fdv1Fallback;

  const ModeDefinition({
    required this.initializers,
    required this.synchronizers,
    this.fdv1Fallback,
  });
}

/// Configuration for the FDv1 fallback tier.
final class Fdv1FallbackConfig {
  /// Minimum polling interval for the fallback synchronizer
  final Duration? pollInterval;

  /// Per-source endpoint overrides.
  final EndpointConfig? endpoints;

  const Fdv1FallbackConfig({this.pollInterval, this.endpoints});
}
