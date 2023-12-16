/// Specifies the base service URLs used by SDK components.
abstract class ServiceEndpoints {
  /// The default polling endpoint.
  String get defaultPolling;

  /// The default streaming endpoint.
  String get defaultStreaming;

  /// The default events endpoint.
  String get defaultEvents;

  /// The base polling url.
  late final String polling;

  /// The base streaming url.
  late final String streaming;

  /// The base events url.
  late final String events;

  /// Construct custom service endpoints.
  ///
  /// In typical SDK usage custom endpoints are not required. When custom
  /// endpoints are required it is recommended that each endpoint is set.
  ///
  /// For debugging purposes a single endpoint may be set, such as using ngrok
  /// to inspect generated events.
  ServiceEndpoints.custom({String? polling, String? streaming, String? events}) {
    this.polling = polling ?? defaultPolling;
    this.streaming = streaming ?? defaultStreaming;
    this.events = events ?? defaultEvents;
  }

  /// Construct service endpoints for use with relay proxy.
  ServiceEndpoints.relayProxy(url)
      : polling = url,
        streaming = url,
        events = url;

  /// Construct a default set of service endpoints.
  ServiceEndpoints() {
    polling = defaultPolling;
    streaming = defaultStreaming;
    events = defaultEvents;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceEndpoints &&
          polling == other.polling &&
          streaming == other.streaming &&
          events == other.events;

  @override
  int get hashCode => polling.hashCode ^ streaming.hashCode ^ events.hashCode;
}
