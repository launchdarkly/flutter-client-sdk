import 'stub_config.dart'
    if (dart.library.io) 'io_config.dart'
    if (dart.library.js_interop) 'js_config.dart';

/// Configuration common to web and mobile is contained in this file.
///
/// Configuration specific to either io targets or js targets are in io_config
/// and js_config and then exposed through this file.

final class DefaultEventConfiguration {
  final defaultEventsCapacity = 100;
  final defaultFlushInterval = Duration(seconds: 30);
  final defaultDiagnosticRecordingInterval = Duration(minutes: 15);
  final minDiagnosticRecordingInterval = Duration(minutes: 5);
}

final class DefaultPollingConfiguration {
  final defaultPollingInterval = Duration(minutes: 5);
  final minPollingInterval = Duration(minutes: 5);
}

final class DefaultPersistenceConfig {
  final defaultMaxCachedContexts = 5;
}

final class DefaultConfig {
  static final pollingPaths = DefaultPollingPaths();
  static final streamingPaths = DefaultStreamingPaths();
  static final eventPaths = DefaultEventPaths();
  static final DefaultEndpoints endpoints = DefaultEndpoints();
  static final eventConfig = DefaultEventConfiguration();
  static final pollingConfig = DefaultPollingConfiguration();
  static final dataSourceConfig = DefaultDataSourceConfig();
  static final credentialConfig = CredentialConfig();
  static final persistenceConfig = DefaultPersistenceConfig();
  static final bool defaultOffline = false;
  static final bool allAttributesPrivate = false;
}
