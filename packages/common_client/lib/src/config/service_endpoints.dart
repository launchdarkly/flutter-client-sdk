import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart' as common;

import 'defaults/default_config.dart';

/// Specifies the base service URLs used by SDK components.
final class ServiceEndpoints extends common.ServiceEndpoints {
  @override
  String get defaultPolling => DefaultConfig.endpoints.polling;

  @override
  String get defaultEvents => DefaultConfig.endpoints.events;

  @override
  String get defaultStreaming => DefaultConfig.endpoints.streaming;

  /// Construct custom service endpoints.
  ///
  /// In typical SDK usage custom endpoints are not required. When custom
  /// endpoints are required it is recommended that each endpoint is set.
  ///
  /// For debugging purposes a single endpoint may be set, such as using ngrok
  /// to inspect generated events.
  ServiceEndpoints.custom({super.polling, super.streaming, super.events})
      : super.custom();

  /// Construct service endpoints for use with relay proxy.
  ServiceEndpoints.relayProxy(super.url) : super.relayProxy();

  /// Construct a default set of service endpoints.
  ServiceEndpoints() : super();
}
