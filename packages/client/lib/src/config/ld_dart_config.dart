import 'package:launchdarkly_dart_common/ld_common.dart'
    show LDLogger, HttpProperties;

import '../persistence.dart';
import 'data_source_config.dart';
import 'events_config.dart';
import 'service_endpoints.dart';

final class LDDartConfig {
  // TODO: Implement configuration.
  final String sdkCredential;
  final LDLogger logger;
  final Persistence? persistence;
  final ServiceEndpoints endpoints;
  final PollingDataSourceConfig pollingConfig;
  final StreamingDataSourceConfig streamingConfig;
  final HttpProperties httpProperties;
  final EventsConfig eventsConfig;

  // TODO: Builder?
  LDDartConfig(
      {required this.sdkCredential,
      LDLogger? logger,
      ServiceEndpoints? endpoints,
      PollingDataSourceConfig? pollingConfig,
      StreamingDataSourceConfig? streamingConfig,
      HttpProperties? httpProperties,
      EventsConfig? eventsConfig,
      this.persistence})
      : logger = logger ?? LDLogger(),
        endpoints = endpoints ?? ServiceEndpoints(),
        pollingConfig = pollingConfig ?? PollingDataSourceConfig(),
        httpProperties = httpProperties ?? HttpProperties(),
        eventsConfig = eventsConfig ?? EventsConfig(),
        streamingConfig = streamingConfig ?? StreamingDataSourceConfig();
}
