import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import '../../config/defaults/default_config.dart';
import '../../config/service_endpoints.dart';
import '../sse_client_factory.dart';
import '../streaming_data_source.dart' show LDLoggerToEventSourceAdapter;
import 'cache_initializer.dart' as cache_src;
import 'endpoints.dart';
import 'protocol_types.dart';
import 'source_factory_context.dart';
import 'mode_definition.dart' as mode;
import 'polling_base.dart';
import 'polling_initializer.dart';
import 'polling_synchronizer.dart';
import 'requestor.dart';
import 'selector.dart';
import 'source.dart';
import 'streaming_base.dart';
import 'streaming_synchronizer.dart';

/// Merges per-entry [mode.EndpointConfig] overrides into [base].
ServiceEndpoints mergeServiceEndpoints(
  ServiceEndpoints base,
  mode.EndpointConfig? override,
) {
  if (override == null) {
    return base;
  }
  if (override.pollingBaseUri == null && override.streamingBaseUri == null) {
    return base;
  }
  return ServiceEndpoints.custom(
    polling: override.pollingBaseUri?.toString() ?? base.polling,
    streaming: override.streamingBaseUri?.toString() ?? base.streaming,
    events: base.events,
  );
}

/// Builds a fresh [FDv2PollingBase] (and its underlying [FDv2Requestor]) per
/// call. Must be invoked inside the factory's `create` lambda so each
/// produced instance owns its own requestor; the requestor holds mutable
/// per-call state (e.g. ETag) and cannot be safely shared across instances.
FDv2PollingBase _buildPollingBase({
  required mode.EndpointConfig? endpoints,
  required SourceFactoryContext ctx,
}) {
  final endpointsResolved =
      mergeServiceEndpoints(ctx.serviceEndpoints, endpoints);
  final requestor = FDv2Requestor(
    logger: ctx.logger,
    endpoints: endpointsResolved,
    contextEncoded: base64UrlEncode(utf8.encode(ctx.contextJson)),
    contextJson: ctx.contextJson,
    usePost: ctx.usePost,
    withReasons: ctx.withReasons,
    additionalQueryParameters: ctx.additionalQueryParameters,
    httpProperties: ctx.httpProperties,
    httpClientFactory: ctx.httpClientFactory ?? _defaultHttpClientFactory,
  );
  return FDv2PollingBase(
    logger: ctx.logger,
    requestor: requestor,
  );
}

HttpClient _defaultHttpClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

/// FDv2 event names subscribed on the streaming connection. Includes the
/// legacy `ping` bridge event.
const Set<String> _fdv2StreamEventNames = {
  FDv2EventTypes.serverIntent,
  FDv2EventTypes.putObject,
  FDv2EventTypes.deleteObject,
  FDv2EventTypes.payloadTransferred,
  FDv2EventTypes.goodbye,
  FDv2EventTypes.error,
  FDv2EventTypes.heartbeat,
  'ping',
};

/// Builds the [SSEClient] for a streaming source.
///
/// When the context travels in a POST body, the client must report
/// [SSECapability.customMethod]. Without it, this logs a warning, closes the
/// client, and builds a new client that uses GET.
SSEClient _buildSseClient({
  required SSEClientFactory factory,
  required bool customFactory,
  required SourceFactoryContext ctx,
  required Uri Function() Function(bool usePost) uriProviderFor,
}) {
  SSEClient build(bool usePost) => factory(SSEClientRequest(
        uriProvider: uriProviderFor(usePost),
        eventTypes: _fdv2StreamEventNames,
        headers: streamingRequestHeaders(ctx.httpProperties,
            customFactory: customFactory),
        body: usePost ? ctx.contextJson : null,
        method: usePost ? SseHttpMethod.post : SseHttpMethod.get,
        logger: LDLoggerToEventSourceAdapter(ctx.logger),
      ));

  final client = build(ctx.usePost);
  if (ctx.usePost && !client.hasCapability(SSECapability.customMethod)) {
    ctx.logger.warn(
        'The SSE client cannot send POST requests. Streaming with GET instead.');
    client.close();
    return build(false);
  }
  return client;
}

/// Builds the streaming URI for the current state. Invoked per
/// connection attempt so the `basis` parameter tracks the selector.
Uri _buildStreamingUri({
  required ServiceEndpoints endpoints,
  required String contextEncoded,
  required bool usePost,
  required bool withReasons,
  required Selector basis,
  Map<String, String> additionalQueryParameters = const {},
}) {
  final addedPath = usePost
      ? FDv2Endpoints.streaming
      : FDv2Endpoints.streamingGet(contextEncoded);
  return buildFDv2Uri(
    baseUri: Uri.parse(endpoints.streaming),
    addedPath: addedPath,
    withReasons: withReasons,
    basis: basis,
    additionalQueryParameters: additionalQueryParameters,
  );
}

/// A factory for creating [Initializer] instances.
final class InitializerFactory {
  /// True for cache initializers.
  final bool isCache;

  final Initializer Function(SelectorGetter selectorGetter) _create;

  InitializerFactory({
    required Initializer Function(SelectorGetter selectorGetter) create,
    this.isCache = false,
  }) : _create = create;

  Initializer create(SelectorGetter selectorGetter) => _create(selectorGetter);
}

/// A factory for creating [Synchronizer] instances.
final class SynchronizerFactory {
  final Synchronizer Function(SelectorGetter selectorGetter) _create;

  SynchronizerFactory({
    required Synchronizer Function(SelectorGetter selectorGetter) create,
  }) : _create = create;

  Synchronizer create(SelectorGetter selectorGetter) => _create(selectorGetter);
}

/// Builds an [InitializerFactory] for a single [mode.InitializerEntry].
///
/// Throws [UnsupportedError] for unsupported entry types.
InitializerFactory createInitializerFactoryFromEntry(
  mode.InitializerEntry entry,
  SourceFactoryContext ctx,
) {
  switch (entry) {
    case mode.CacheInitializer():
      return InitializerFactory(
        isCache: true,
        create: (_) => cache_src.CacheInitializer(
          reader: ctx.cachedFlagsReader,
          context: ctx.context,
          logger: ctx.logger,
        ),
      );
    case final mode.PollingInitializer e:
      return InitializerFactory(
        create: (SelectorGetter selectorGetter) {
          final base = _buildPollingBase(
            endpoints: e.endpoints,
            ctx: ctx,
          );
          return FDv2PollingInitializer(
            poll: ({Selector basis = Selector.empty}) =>
                base.pollOnce(basis: basis),
            selectorGetter: selectorGetter,
            logger: ctx.logger,
          );
        },
      );
    case mode.StreamingInitializer():
      throw UnsupportedError(
        'FDv2 StreamingInitializer factories are not implemented yet',
      );
  }
}

/// Builds a [SynchronizerFactory] for a single [mode.SynchronizerEntry].
SynchronizerFactory createSynchronizerFactoryFromEntry(
  mode.SynchronizerEntry entry,
  SourceFactoryContext ctx, {
  SSEClientFactory? sseClientFactory,
}) {
  switch (entry) {
    case final mode.PollingSynchronizer e:
      final interval = e.pollInterval ?? ctx.defaultPollingInterval;
      return SynchronizerFactory(
        create: (SelectorGetter selectorGetter) {
          final base = _buildPollingBase(
            endpoints: e.endpoints,
            ctx: ctx,
          );
          return FDv2PollingSynchronizer(
            poll: ({Selector basis = Selector.empty}) =>
                base.pollOnce(basis: basis),
            selectorGetter: selectorGetter,
            interval: interval,
            logger: ctx.logger,
          );
        },
      );
    case final mode.StreamingSynchronizer e:
      return SynchronizerFactory(
        create: (SelectorGetter selectorGetter) {
          final endpointsResolved =
              mergeServiceEndpoints(ctx.serviceEndpoints, e.endpoints);
          final sseClient = _buildSseClient(
            factory: sseClientFactory ?? defaultSseClientFactory,
            customFactory: sseClientFactory != null,
            ctx: ctx,
            uriProviderFor: (usePost) => () => _buildStreamingUri(
                  endpoints: endpointsResolved,
                  contextEncoded: base64UrlEncode(utf8.encode(ctx.contextJson)),
                  usePost: usePost,
                  withReasons: ctx.withReasons,
                  basis: selectorGetter(),
                  additionalQueryParameters: ctx.additionalQueryParameters,
                ),
          );

          // Legacy ping events trigger a one-shot poll.
          final pingPollingBase = _buildPollingBase(
            endpoints: e.endpoints,
            ctx: ctx,
          );

          return FDv2StreamingSynchronizer(
            base: FDv2StreamingBase(
              sseClient: sseClient,
              pingHandler: () =>
                  pingPollingBase.pollOnce(basis: selectorGetter()),
              logger: ctx.logger,
              // Used when the transport exposes no response headers (the
              // browser EventSource) to read x-ld-envid from.
              defaultEnvironmentId: DefaultConfig.credentialConfig
                  .environmentIdFallback(ctx.credential),
            ),
          );
        },
      );
  }
}

/// One factory per entry, in list order.
List<InitializerFactory> buildInitializerFactories(
  List<mode.InitializerEntry> entries,
  SourceFactoryContext ctx,
) {
  return entries.map((e) => createInitializerFactoryFromEntry(e, ctx)).toList();
}

/// One factory per entry, in list order.
List<SynchronizerFactory> buildSynchronizerFactories(
  List<mode.SynchronizerEntry> entries,
  SourceFactoryContext ctx, {
  SSEClientFactory? sseClientFactory,
}) {
  return entries
      .map((e) => createSynchronizerFactoryFromEntry(e, ctx,
          sseClientFactory: sseClientFactory))
      .toList();
}
