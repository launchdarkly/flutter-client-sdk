import 'package:launchdarkly_dart_common/ld_common.dart';

import '../persistence.dart';
import 'data_source_config.dart';
import 'events_config.dart';

final class LDDartConfig {
  // TODO: Implement configuration.
  final String sdkCredential;
  final LDLogger logger;
  final Persistence? persistence;
  final ServiceEndpoints endpoints;
  final PollingDataSourceConfig pollingConfig;
  final HttpProperties httpProperties;
  final EventsConfig eventsConfig;

  // TODO: Builder?
  LDDartConfig(
      {required this.sdkCredential,
      required this.logger,
      required this.endpoints,
      required this.pollingConfig,
        required this.httpProperties,
        required this.eventsConfig,
      this.persistence});
}
