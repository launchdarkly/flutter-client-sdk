import 'dart:convert';

import 'package:launchdarkly_dart_common/ld_common.dart';
import '../item_descriptor.dart';
import '../persistence/persistence.dart';
import 'context_index.dart';
import 'flag_updater.dart';
import 'flag_store.dart';

const String _globalNamespace = 'LaunchDarkly';
const String _indexKey = 'ContextIndex';

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

  Future<void> init(LDContext context, Map<String, ItemDescriptor> newFlags) async {
    _updater.init(context, newFlags);
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

  Future<bool> loadCached(LDContext context) async {
    final json = await _persistence?.read(
        _environmentKey, encodePersistenceKey(context.canonicalKey));

    if (json == null) {
      return false;
    }

    try {
      final flagConfig =
          LDEvaluationResultsSerialization.fromJson(jsonDecode(json));

      _updater.initCached(
          context,
          flagConfig.map((key, value) => MapEntry(
              key, ItemDescriptor(version: value.version, flag: value))));
      return true;
    } catch (e) {
      _logger.warn('Could not load cached flag values for context: $e');
      return false;
    }
  }

  Future<void> _loadIndex() async {
    if (_contextIndex != null) {
      return;
    }
    final json = await _persistence?.read(_environmentKey, _indexKey);
    if (json != null) {
      try {
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

    final contextPersistenceKey = encodePersistenceKey(context.canonicalKey);
    _contextIndex!.notice(contextPersistenceKey, _stamper());

    final pruned = _contextIndex!.prune(maxCachedContexts);
    for (var id in pruned) {
      await _persistence?.remove(_environmentKey, id);
    }

    await _persistence?.set(
        _environmentKey, _indexKey, jsonEncode(_contextIndex!.toJson()));

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
    await _persistence?.set(_environmentKey, contextPersistenceKey, jsonAll);
  }
}
