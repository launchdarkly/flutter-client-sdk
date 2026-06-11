class NetworkConfig {
  Duration get connectTimeout => const Duration(seconds: 10);

  Duration get readTimeout => const Duration(seconds: 10);

  Duration get writeTimeout => const Duration(seconds: 10);

  Set<String> get restrictedHeaders => {'user-agent', 'authorization'};

  const NetworkConfig();
}
