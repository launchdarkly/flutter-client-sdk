import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;

import '../../config/service_endpoints.dart';
import 'cache_initializer.dart' as cache_src;
import 'source_factory_context.dart';
import 'mode_definition.dart' as mode;
import 'polling_base.dart';
import 'polling_initializer.dart';
import 'polling_synchronizer.dart';
import 'requestor.dart';
import 'selector.dart';
import 'source.dart';

/// Merges optional per-entry [mode.EndpointConfig] overrides into [base].
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

FDv2PollingBase _sharedPollingBase({
  required mode.EndpointConfig? endpoints,
  required bool usePost,
  required SourceFactoryContext ctx,
}) {
  final endpointsResolved =
      mergeServiceEndpoints(ctx.serviceEndpoints, endpoints);
  final requestor = FDv2Requestor(
    logger: ctx.logger,
    endpoints: endpointsResolved,
    contextEncoded: base64UrlEncode(utf8.encode(ctx.contextJson)),
    contextJson: ctx.contextJson,
    usePost: usePost,
    withReasons: ctx.withReasons,
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

/// A factory for creating [Initializer] instances.
final class InitializerFactory {
  /// True for cache initializers ([CONNMODE] / CSFDv2 cache-miss success rule).
  final bool isCache;

  final Initializer Function(SelectorGetter selectorGetter) _create;

  InitializerFactory({
    required Initializer Function(SelectorGetter selectorGetter) create,
    this.isCache = false,
  }) : _create = create;

  /// Returns a **new** [Initializer] bound to [selectorGetter] (or ignores it
  /// for cache, matching JS).
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
      final base = _sharedPollingBase(
        endpoints: e.endpoints,
        usePost: e.usePost,
        ctx: ctx,
      );
      return InitializerFactory(
        create: (SelectorGetter selectorGetter) => FDv2PollingInitializer(
          poll: ({Selector basis = Selector.empty}) =>
              base.pollOnce(basis: basis),
          selectorGetter: selectorGetter,
          logger: ctx.logger,
        ),
      );
    case mode.StreamingInitializer():
      throw UnsupportedError(
        'FDv2 StreamingInitializer factories are not implemented yet',
      );
  }
}

/// Builds a [SynchronizerFactory] for a single [mode.SynchronizerEntry].
///
/// Throws [UnsupportedError] for unsupported entry types.
SynchronizerFactory createSynchronizerFactoryFromEntry(
  mode.SynchronizerEntry entry,
  SourceFactoryContext ctx,
) {
  switch (entry) {
    case final mode.PollingSynchronizer e:
      final base = _sharedPollingBase(
        endpoints: e.endpoints,
        usePost: e.usePost,
        ctx: ctx,
      );
      final interval = e.pollInterval ?? ctx.defaultPollingInterval;
      return SynchronizerFactory(
        create: (SelectorGetter selectorGetter) => FDv2PollingSynchronizer(
          poll: ({Selector basis = Selector.empty}) =>
              base.pollOnce(basis: basis),
          selectorGetter: selectorGetter,
          interval: interval,
          logger: ctx.logger,
        ),
      );
    case mode.StreamingSynchronizer():
      throw UnsupportedError(
        'FDv2 StreamingSynchronizer factories are not implemented yet',
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
  SourceFactoryContext ctx,
) {
  return entries
      .map((e) => createSynchronizerFactoryFromEntry(e, ctx))
      .toList();
}
