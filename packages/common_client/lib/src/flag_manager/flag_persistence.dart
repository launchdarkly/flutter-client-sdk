import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import '../data_sources/fdv2/payload.dart';
import '../item_descriptor.dart';
import '../persistence/persistence.dart';
import 'context_index.dart';
import 'flag_updater.dart';
import 'flag_store.dart';

const String _globalNamespace = 'LaunchDarkly';
const String _indexKey = 'ContextIndex';
const String _envIdKey = 'EnvironmentId';

String _makeEnvironment(String sdkKey) {
  return '${_globalNamespace}_${encodePersistenceKey(sdkKey)}';
}

DateTime _defaultStamper() => DateTime.now();

/// This class handles persisting and loading flag values from a persistent
/// store. It intercepts updates and forwards them to the flag updater and
/// then persists changes after the updater has completed.
final class FlagPersistence {
  final Persistence? _persistence;
  final FlagUpdater _updater;
  final String _environmentKey;
  ContextIndex? _contextIndex;
  final int maxCachedContexts;
  final FlagStore _store;
  final DateTime Function() _stamper;
  final LDLogger _logger;

  FlagPersistence(
      {Persistence? persistence,
      required FlagUpdater updater,
      required String sdkKey,
      required this.maxCachedContexts,
      required FlagStore store,
      required LDLogger logger,
      // This is primarily to allow overwriting the default time stamping for testing.
      DateTime Function() stamper = _defaultStamper})
      : _persistence = persistence,
        _updater = updater,
        _environmentKey = _makeEnvironment(sdkKey),
        _store = store,
        _logger = logger.subLogger('FlagPersistence'),
        _stamper = stamper;

  Future<void> init(LDContext context, Map<String, ItemDescriptor> newFlags,
      {String? environmentId}) async {
    _updater.init(context, newFlags, environmentId: environmentId);
    return _storeCache(context);
  }

  Future<bool> upsert(
      LDContext context, String key, ItemDescriptor item) async {
    if (_updater.upsert(context, key, item)) {
      // We only need to store the cache if there was an update.
      // This is executed asynchronously.
      await _storeCache(context);
      return true;
    }
    return false;
  }

  Future<bool> applyChanges(
      LDContext context, Map<String, ItemDescriptor> updates, PayloadType type,
      {String? environmentId}) async {
    if (_updater.applyChanges(context, updates, type,
        environmentId: environmentId)) {
      // A transfer of none, or a partial transfer with no updates, changes
      // nothing, so the cache write is skipped. A full transfer always
      // writes; replacing the stored flags with an empty set is a change.
      if (type == PayloadType.full ||
          (type == PayloadType.partial && updates.isNotEmpty)) {
        await _storeCache(context);
      }
      return true;
    }
    return false;
  }

  /// Reads the cached flag state for [context] from persistence without
  /// applying it to the store. Returns null on a cache miss, an
  /// unreadable entry, or a parse failure.
  Future<({Map<String, LDEvaluationResult> flags, String? environmentId})?>
      readCached(LDContext context) async {
    final json = await _persistence?.read(
        _environmentKey, encodePersistenceKey(context.canonicalKey));

    if (json == null) {
      return null;
    }

    final environmentId = await _persistence?.read(_environmentKey, _envIdKey);

    try {
      final flagConfig =
          LDEvaluationResultsSerialization.fromJson(jsonDecode(json));
      return (flags: flagConfig, environmentId: environmentId);
    } catch (e) {
      _logger.warn('Could not load cached flag values for context: $e');
      return null;
    }
  }

  Future<bool> loadCached(LDContext context, {Future<void>? cancelled}) async {
    // Stop waiting for the read if the load is cancelled.
    final cached = await Future.any([
      readCached(context),
      if (cancelled != null) cancelled.then((_) => null),
    ]);
    if (cached == null) {
      return false;
    }

    _updater.initCached(
        context,
        cached.flags.map((key, value) =>
            MapEntry(key, ItemDescriptor(version: value.version, flag: value))),
        environmentId: cached.environmentId);
    _logger.debug('Loaded a cached flag config from persistence.');
    return true;
  }

  Future<void> _loadIndex() async {
    if (_contextIndex != null) {
      return;
    }
    final json = await _persistence?.read(_environmentKey, _indexKey);
    if (json != null) {
      try {
        _logger.debug('Loaded context index from persistence.');
        _contextIndex = ContextIndex.fromJson(jsonDecode(json));
      } catch (e) {
        _logger.warn('Could not load index from persistent storage: $e');
      }
    }

    // Either didn't exist, or encountered an error during loading.
    _contextIndex ??= ContextIndex();
  }

  Future<void> _storeCache(LDContext context) async {
    await _loadIndex();

    // Will be set via _loadIndex non-conditionally.
    assert(_contextIndex != null);

    // Skip the write when the store holds another context's flags.
    if (!_updater.isActive(context)) {
      return;
    }

    // The store can change during the writes, so compute their data first.
    final contextPersistenceKey = encodePersistenceKey(context.canonicalKey);
    _contextIndex!.notice(contextPersistenceKey, _stamper());
    final pruned = _contextIndex!.prune(maxCachedContexts);
    // Whether this context is still in the index after the prune.
    final indexed = !pruned.contains(contextPersistenceKey);
    final jsonIndex = jsonEncode(_contextIndex!.toJson());
    final allFlags = _store.getAll();
    final filteredFlags = <String, LDEvaluationResult>{};
    // We only persist the non-deleted flags as LDEvaluationResult.
    for (var MapEntry(key: key, value: value) in allFlags.entries) {
      if (value.flag != null) {
        filteredFlags[key] = value.flag!;
      }
    }
    final jsonAll =
        jsonEncode(LDEvaluationResultsSerialization.toJson(filteredFlags));
    final environmentId = _store.environmentId;

    final persistence = _persistence;
    if (persistence == null) {
      return;
    }
    // Start every write before awaiting, so a later call's writes land last.
    await Future.wait([
      for (var id in pruned) persistence.remove(_environmentKey, id),
      persistence.set(_environmentKey, _indexKey, jsonIndex),
      if (indexed)
        persistence.set(_environmentKey, contextPersistenceKey, jsonAll),
      // There will be a singular environment ID for a given environment key
      // (credential).
      if (indexed && environmentId != null)
        persistence.set(_environmentKey, _envIdKey, environmentId),
    ]);
  }
}
