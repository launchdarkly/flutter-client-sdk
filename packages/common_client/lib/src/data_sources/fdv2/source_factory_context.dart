import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;

import '../../config/defaults/default_config.dart';
import '../../config/service_endpoints.dart';
import 'cache_initializer.dart';
import 'requestor.dart';

/// Shared dependencies for building [InitializerFactory] and [SynchronizerFactory]
/// factories from [ModeDefinition] entries (see [createInitializerFactoryFromEntry],
/// [createSynchronizerFactoryFromEntry]).
final class SourceFactoryContext {
  final LDContext context;

  final LDLogger logger;

  final HttpProperties httpProperties;

  final ServiceEndpoints serviceEndpoints;

  final String contextJson;

  final bool withReasons;

  final Duration defaultPollingInterval;

  final CachedFlagsReader cachedFlagsReader;

  final HttpClientFactory? httpClientFactory;

  /// The SDK credential. Used as the environment identifier when the
  /// platform's credential is a client-side ID.
  final String credential;

  /// Authentication query parameters, applied to every data acquisition
  /// request on platforms that authenticate with the `auth` query
  /// parameter (browsers). Empty on platforms that authenticate with the
  /// authorization header in the base headers (mobile keys).
  final Map<String, String> authQueryParameters;

  const SourceFactoryContext({
    required this.context,
    required this.logger,
    required this.httpProperties,
    required this.serviceEndpoints,
    required this.contextJson,
    required this.withReasons,
    required this.defaultPollingInterval,
    required this.cachedFlagsReader,
    required this.credential,
    this.authQueryParameters = const {},
    this.httpClientFactory,
  });

  factory SourceFactoryContext.fromClientConfig({
    required LDContext context,
    required LDLogger logger,
    required HttpProperties httpProperties,
    required ServiceEndpoints serviceEndpoints,
    required bool withReasons,
    required Duration defaultPollingInterval,
    required CachedFlagsReader cachedFlagsReader,
    required String credential,
    HttpClientFactory? httpClientFactory,
  }) {
    final plainContextString =
        jsonEncode(LDContextSerialization.toJson(context, isEvent: false));
    return SourceFactoryContext(
      context: context,
      logger: logger,
      httpProperties: httpProperties,
      serviceEndpoints: serviceEndpoints,
      contextJson: plainContextString,
      withReasons: withReasons,
      defaultPollingInterval: defaultPollingInterval,
      cachedFlagsReader: cachedFlagsReader,
      credential: credential,
      authQueryParameters:
          DefaultConfig.credentialConfig.authQueryParameters(credential),
      httpClientFactory: httpClientFactory,
    );
  }
}
