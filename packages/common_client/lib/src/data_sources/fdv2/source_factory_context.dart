import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../../config/defaults/credential_type.dart';
import '../../config/defaults/default_config.dart';
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

  /// Query parameters added to every FDv2 request for authentication.
  /// Empty when the credential is carried in the authorization header
  /// (mobile keys). For client-side IDs this carries `auth=<credential>`,
  /// since the browser's native EventSource cannot send custom headers.
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
      authQueryParameters: switch (
          DefaultConfig.credentialConfig.credentialType) {
        // A mobile key is sent in the authorization header on every
        // request via the configured HTTP properties.
        CredentialType.mobileKey => const {},
        // A client-side ID authenticates via the auth query parameter:
        // FDv2 paths do not embed the credential, and the browser's
        // native EventSource cannot send custom headers.
        CredentialType.clientSideId => {'auth': credential},
      },
      httpClientFactory: httpClientFactory,
    );
  }
}
