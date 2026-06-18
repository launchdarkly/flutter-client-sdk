import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;

import '../../config/data_system_config.dart';
import '../../config/service_endpoints.dart';
import '../../fdv2_connection_mode.dart';
import '../data_source_manager.dart';
import '../data_source_status_manager.dart';
import 'built_in_modes.dart';
import 'cache_initializer.dart';
import 'entry_factories.dart';
import 'mode_definition.dart';
import 'orchestrator.dart';
import 'requestor.dart';
import 'selector.dart';
import 'source_factory_context.dart';
import 'source_manager.dart';

/// Composes the FDv2 data source factories consumed by the
/// DataSourceManager and owns the selector, which must outlive any single
/// orchestrator instance.
///
/// A fresh orchestrator is created per connection-mode switch and per
/// identify. The selector survives mode switches (initializers are
/// skipped when a selector is held). It is specific to a single context,
/// so it must be reset on a context change; that is driven explicitly by
/// the data manager via [clearSelector] at identify time rather than
/// inferred here from the context instance, which depends on the factory
/// being invoked for every change.
final class FDv2DataSystem {
  final String _credential;
  final LDLogger _logger;
  final HttpProperties _httpProperties;
  final ServiceEndpoints _serviceEndpoints;
  final bool _withReasons;
  final Duration _defaultPollingInterval;
  final DataSourceStatusManager _statusManager;
  final Map<ConnectionModeId, ModeDefinition> _connectionModeOverrides;
  final CachedFlagsReader _cachedFlagsReader;
  final FDv2SseClientFactory _sseClientFactory;
  final HttpClientFactory? _httpClientFactory;

  Selector _selector = Selector.empty;

  FDv2DataSystem({
    required DataSystemConfig config,
    required String credential,
    required LDLogger logger,
    required HttpProperties httpProperties,
    required ServiceEndpoints serviceEndpoints,
    required bool withReasons,
    required Duration defaultPollingInterval,
    required DataSourceStatusManager statusManager,
    required CachedFlagsReader cachedFlagsReader,
    FDv2SseClientFactory sseClientFactory = defaultSseClientFactory,
    HttpClientFactory? httpClientFactory,
  })  : _credential = credential,
        _logger = logger,
        _httpProperties = httpProperties,
        _serviceEndpoints = serviceEndpoints,
        _withReasons = withReasons,
        _defaultPollingInterval = defaultPollingInterval,
        _statusManager = statusManager,
        _cachedFlagsReader = cachedFlagsReader,
        _sseClientFactory = sseClientFactory,
        _httpClientFactory = httpClientFactory,
        _connectionModeOverrides = config.connectionModes;

  /// The definition for a built-in mode: the user's override if one was
  /// given for it, otherwise the built-in default.
  ModeDefinition _resolve(ConnectionModeId mode, ModeDefinition builtIn) =>
      _connectionModeOverrides[mode] ?? builtIn;

  /// Discards the held selector so the next source rebuilds a basis from
  /// its initializers. Called when identifying a new context, since a
  /// selector points at one context's data and cannot seed a delta for
  /// another. Mode switches keep the selector and so do not call this.
  void clearSelector() {
    _selector = Selector.empty;
  }

  /// Produces the factory map for the DataSourceManager. Offline is a
  /// real pipeline mode: its data source runs the cache initializer with
  /// no synchronizer, so the SDK serves cached flags while offline. The
  /// manager reports the offline status itself; the offline source's
  /// payload does not drive the status to valid.
  Map<FDv2ConnectionMode, DataSourceFactory> buildFactories() {
    return {
      const FDv2Streaming(): _factoryForMode(
          _resolve(ConnectionModeId.streaming, BuiltInModes.streaming)),
      const FDv2Polling(): _factoryForMode(
          _resolve(ConnectionModeId.polling, BuiltInModes.polling)),
      const FDv2Background(): _factoryForMode(
          _resolve(ConnectionModeId.background, BuiltInModes.background)),
      const FDv2Offline(): _factoryForMode(
          _resolve(ConnectionModeId.offline, BuiltInModes.offline)),
    };
  }

  DataSourceFactory _factoryForMode(ModeDefinition modeDefinition) {
    return (LDContext context) {
      final factoryContext = SourceFactoryContext.fromClientConfig(
        context: context,
        credential: _credential,
        logger: _logger,
        httpProperties: _httpProperties,
        serviceEndpoints: _serviceEndpoints,
        withReasons: _withReasons,
        defaultPollingInterval: _defaultPollingInterval,
        // The FDv2 data system owns cache loading: the cache initializer
        // reads persistence through this reader and feeds the result into
        // the pipeline, rather than the client applying it at identify.
        cachedFlagsReader: _cachedFlagsReader,
        httpClientFactory: _httpClientFactory,
      );

      // When a selector is held the SDK already has basis data for this
      // context; mode switches go straight to synchronizers.
      final includeInitializers = _selector.isEmpty;
      final initializerFactories = includeInitializers
          ? buildInitializerFactories(
              modeDefinition.initializers, factoryContext)
          : <InitializerFactory>[];

      // The FDv1 fallback tier (modeDefinition.fdv1Fallback) is not built
      // into a slot yet. When it is, mark that slot isFdv1Fallback and keep
      // its source incapable of emitting a result with fdv1Fallback set:
      // it is the terminal tier, so re-asserting the directive from there
      // would drive the orchestrator to re-engage FDv1 fallback on every
      // result, undelayed and blocking no slot. A source that cannot emit
      // the directive is simpler than guarding the orchestrator against
      // re-engaging while already on FDv1.
      final synchronizerSlots = buildSynchronizerFactories(
              modeDefinition.synchronizers, factoryContext,
              sseClientFactory: _sseClientFactory)
          .map((factory) => SynchronizerSlot(factory: factory))
          .toList();

      return FDv2DataSourceOrchestrator(
        initializerFactories: initializerFactories,
        synchronizerSlots: synchronizerSlots,
        selectorGetter: () => _selector,
        selectorUpdater: (selector) => _selector = selector,
        statusManager: _statusManager,
        logger: _logger,
      );
    };
  }
}
