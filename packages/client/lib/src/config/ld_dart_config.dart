import 'package:launchdarkly_dart_common/ld_common.dart'
    show ApplicationInfo, LDLogger, HttpProperties;
import 'package:launchdarkly_dart_common/ld_common.dart'
    show EnvironmentReporter, ConcreteEnvReporter;

import '../persistence/persistence.dart';
import 'data_source_config.dart';
import 'events_config.dart';
import 'service_endpoints.dart';

final class LDDartConfig {
  // TODO: Implement configuration.
  final String sdkCredential;
  final ApplicationInfo? applicationInfo;
  final LDLogger logger;
  final Persistence? persistence;
  final ServiceEndpoints endpoints;
  final PollingDataSourceConfig pollingConfig;
  final StreamingDataSourceConfig streamingConfig;
  final HttpProperties httpProperties;
  final EventsConfig eventsConfig;
  final EnvironmentReporter platformEnvReporter;
  final bool autoEnvAttributes;

  LDDartConfig(
      {required this.sdkCredential,
      this.applicationInfo,
      LDLogger? logger,
      ServiceEndpoints? endpoints,
      PollingDataSourceConfig? pollingConfig,
      StreamingDataSourceConfig? streamingConfig,
      HttpProperties? httpProperties,
      EventsConfig? eventsConfig,
      this.persistence,
      EnvironmentReporter? platformEnvReporter,
      bool? autoEnvAttributes})
      : logger = logger ?? LDLogger(),
        endpoints = endpoints ?? ServiceEndpoints(),
        pollingConfig = pollingConfig ?? PollingDataSourceConfig(),
        httpProperties = httpProperties ?? HttpProperties(),
        eventsConfig = eventsConfig ?? EventsConfig(),
        streamingConfig = streamingConfig ?? StreamingDataSourceConfig(),
        platformEnvReporter =
            platformEnvReporter ?? ConcreteEnvReporter.ofNulls(),
        autoEnvAttributes = autoEnvAttributes ?? false;
}
