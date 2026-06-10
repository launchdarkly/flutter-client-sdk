import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../../config/data_system_config.dart';
import '../../fdv2_connection_mode.dart';
import '../data_source_manager.dart';
import '../data_source_status_manager.dart';
import 'built_in_modes.dart';
import 'entry_factories.dart';
import 'mode_definition.dart';
import 'orchestrator.dart';
import 'requestor.dart';
import 'selector.dart';
import 'source_factory_context.dart';
import 'source_manager.dart';

/// Composes the FDv2 data source factories consumed by the
/// DataSourceManager and owns the state that must outlive any single
/// orchestrator instance: the current selector and the context it
/// belongs to.
///
/// A fresh orchestrator is created per connection-mode switch and per
/// identify. The selector survives mode switches (initializers are
/// skipped when a selector is held) but is reset whenever the context
/// changes, since a selector is specific to a single context.
final class FDv2DataSystem {
  final String _credential;
  final LDLogger _logger;
  final HttpProperties _httpProperties;
  final ServiceEndpoints _serviceEndpoints;
  final bool _withReasons;
  final Duration _defaultPollingInterval;
  final DataSourceStatusManager _statusManager;
  final Map<String, ModeDefinition> _modeTable;
  final FDv2SseClientFactory? _sseClientFactory;
  final HttpClientFactory? _httpClientFactory;

  Selector _selector = Selector.empty;
  LDContext? _lastContext;

  FDv2DataSystem({
    required DataSystemConfig config,
    required String credential,
    required LDLogger logger,
    required HttpProperties httpProperties,
    required ServiceEndpoints serviceEndpoints,
    required bool withReasons,
    required Duration defaultPollingInterval,
    required DataSourceStatusManager statusManager,
    FDv2SseClientFactory? sseClientFactory,
    HttpClientFactory? httpClientFactory,
  })  : _credential = credential,
        _logger = logger,
        _httpProperties = httpProperties,
        _serviceEndpoints = serviceEndpoints,
        _withReasons = withReasons,
        _defaultPollingInterval = defaultPollingInterval,
        _statusManager = statusManager,
        _sseClientFactory = sseClientFactory,
        _httpClientFactory = httpClientFactory,
        _modeTable = {
          'streaming': BuiltInModes.streaming,
          'polling': BuiltInModes.polling,
          'background': BuiltInModes.background,
          ...config.customConnectionModes,
        };

  /// Produces the factory map for the DataSourceManager. Offline carries
  /// no factory; the manager handles offline without a data source.
  Map<FDv2ConnectionMode, DataSourceFactory> buildFactories() {
    return {
      const FDv2Streaming(): _factoryForMode(_modeTable['streaming']!),
      const FDv2Polling(): _factoryForMode(_modeTable['polling']!),
      const FDv2Background(): _factoryForMode(_modeTable['background']!),
    };
  }

  DataSourceFactory _factoryForMode(ModeDefinition modeDefinition) {
    return (LDContext context) {
      if (!identical(context, _lastContext)) {
        // A new identify produces a new decorated context instance; a
        // mode switch re-uses the active one. The selector belongs to a
        // single context and must not be reused across identifies.
        _lastContext = context;
        _selector = Selector.empty;
      }

      final factoryContext = SourceFactoryContext.fromClientConfig(
        context: context,
        credential: _credential,
        logger: _logger,
        httpProperties: _httpProperties,
        serviceEndpoints: _serviceEndpoints,
        withReasons: _withReasons,
        defaultPollingInterval: _defaultPollingInterval,
        // The common client loads cached flags into the flag store before
        // the data source starts (FlagManager.loadCached during identify),
        // so the cache is already applied by the time this chain runs.
        // Reporting a miss advances the chain without re-applying it.
        cachedFlagsReader: (_) async => null,
        httpClientFactory: _httpClientFactory,
      );

      // When a selector is held the SDK already has basis data for this
      // context; mode switches go straight to synchronizers.
      final includeInitializers = _selector.isEmpty;
      final initializerFactories = includeInitializers
          ? buildInitializerFactories(
              modeDefinition.initializers, factoryContext)
          : <InitializerFactory>[];

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
