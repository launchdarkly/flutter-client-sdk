import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

String _defaultPolling = 'polling';
String _defaultStreaming = 'streaming';
String _defaultEvents = 'events';

/// A specific SDK implementation would expose a class that sets
/// the default endpoints for that SDK type. For instance ClientServiceEndpoints.
final class MockEndpoints extends ServiceEndpoints {
  @override
  String get defaultPolling => _defaultPolling;

  @override
  String get defaultEvents => _defaultEvents;

  @override
  String get defaultStreaming => _defaultStreaming;

  /// Construct custom service endpoints.
  ///
  /// In typical SDK usage custom endpoints are not required. When custom
  /// endpoints are required it is recommended that each endpoint is set.
  ///
  /// For debugging purposes a single endpoint may be set, such as using ngrok
  /// to inspect generated events.
  MockEndpoints.custom({super.polling, super.streaming, super.events})
      : super.custom();

  /// Construct service endpoints for use with relay proxy.
  MockEndpoints.relayProxy(super.url) : super.relayProxy();

  /// Construct a default set of service endpoints.
  MockEndpoints() : super();
}
