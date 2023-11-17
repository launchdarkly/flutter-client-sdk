import 'package:launchdarkly_dart_common/ld_common.dart';

import '../item_descriptor.dart';
import 'flag_store.dart';
import 'flag_persistence.dart';
import 'flag_updater.dart';
import '../persistence.dart';

/// Top level manager of flags for the client. LDClient should be using this
/// class and not any of the specific instances managed by it. Updates from
/// data sources should be directed to the [init] and [upsert] methods of this
/// class.
final class FlagManager {
  final FlagStore _flagStore = FlagStore();
  late final FlagPersistence _flagPersistence;
  late final FlagUpdater _flagUpdater;
  final int maxCachedContexts;

  final LDLogger _logger;

  FlagManager(
      {Persistence? persistence,
      required String sdkKey,
      required this.maxCachedContexts,
      required LDLogger logger})
      : _logger = logger {
    _flagUpdater = FlagUpdater(flagStore: _flagStore, logger: _logger);
    _flagPersistence = FlagPersistence(
        updater: _flagUpdater,
        store: _flagStore,
        persistence: persistence,
        sdkKey: sdkKey,
        maxCachedContexts: maxCachedContexts,
        logger: _logger);
  }

  /// Attempts to get a flag by key from the current flags.
  ItemDescriptor? get(String key) => _flagStore.get(key);

  /// Gets all the current flags.
  Map<String, ItemDescriptor> getAll() => _flagStore.getAll();

  /// Initializes the flag manager with data from a data source.
  /// Persistence initialization is handled by [FlagPersistence].
  init(LDContext context, Map<String, ItemDescriptor> newFlags) =>
      _flagPersistence.init(context, newFlags);

  /// Attempt to update a flag. If the flag is for the wrong context, or
  /// it is of an older version, then an update will not be performed.
  Future<bool> upsert(LDContext context, String key, ItemDescriptor item) async =>
      _flagPersistence.upsert(context, key, item);

  /// Asynchronously load cached values from persistence.
  loadCached(LDContext context) async {
    return _flagPersistence.loadCached(context);
  }

  /// A broadcast stream which emits events as flag changes occur based either
  /// on loading cached values or updates from the data source.
  Stream<FlagsChangedEvent> get changes => _flagUpdater.changes;
}
