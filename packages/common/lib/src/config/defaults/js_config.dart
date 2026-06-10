class NetworkConfig {
  Duration get connectTimeout => const Duration(seconds: 10);

  Duration get readTimeout => const Duration(seconds: 10);

  Duration get writeTimeout => const Duration(seconds: 10);

  /// Browsers forbid setting the `user-agent` header. The authorization
  /// header is permitted: the service's CORS configuration allows it,
  /// and header authentication is preferred wherever the transport
  /// supports custom headers.
  Set<String> get restrictedHeaders => {'user-agent'};

  const NetworkConfig();
}
