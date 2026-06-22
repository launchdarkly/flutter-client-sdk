import 'dart:async';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show LDContext;

import '../flag_manager/flag_manager.dart';
import 'data_source_manager.dart';

/// Owns the data-acquisition strategy for an identify: how the cache is
/// loaded and when the identify resolves. The FDv1 and FDv2 protocols
/// diverge here, so each has its own implementation; everything else
/// (connection lifecycle, mode switching, event routing) is shared in the
/// [DataSourceManager] that both delegate to.
abstract interface class DataManager {
  /// Brings the SDK to a usable state for [context], resolving when the
  /// manager's data-availability strategy is satisfied.
  ///
  /// When [waitForNetworkResults] is true the returned future resolves
  /// only once network (or otherwise fresh) data has arrived; otherwise it
  /// may resolve as soon as cached data is available.
  Future<void> identify(LDContext context,
      {required bool waitForNetworkResults});
}

/// FDv1 data manager.
///
/// The cache is loaded imperatively at identify time via
/// [FlagManager.loadCached]. A cache hit resolves identify immediately
/// unless the caller is waiting for network results; either way the
/// network connection is started so live data follows.
final class FDv1DataManager implements DataManager {
  final DataSourceManager _dataSourceManager;
  final FlagManager _flagManager;

  FDv1DataManager(this._dataSourceManager, this._flagManager);

  @override
  Future<void> identify(LDContext context,
      {required bool waitForNetworkResults}) async {
    final completer = Completer<void>();
    final loadedFromCache = await _flagManager.loadCached(context);
    _dataSourceManager.identify(context, completer);
    if (loadedFromCache && !waitForNetworkResults) {
      return;
    }
    return completer.future;
  }
}

/// FDv2 data manager.
///
/// The cache is not loaded at identify time; the data source pipeline's
/// cache initializer loads it as the first tier. Identify resolves on the
/// first delivered payload, or -- when waiting for network results -- only
/// on fresh data, so a cache load alone does not satisfy a wait-for-network
/// identify.
///
/// Each identify starts data acquisition fresh: any held selector is
/// discarded via [clearSelector] before connecting, so the new connection
/// re-fetches a full payload rather than resuming a previous context's
/// basis. Mode switches keep the selector and reach the data source manager
/// directly rather than through here, so they are unaffected.
final class FDv2DataManager implements DataManager {
  final DataSourceManager _dataSourceManager;
  final void Function() _clearSelector;

  FDv2DataManager(this._dataSourceManager, this._clearSelector);

  @override
  Future<void> identify(LDContext context,
      {required bool waitForNetworkResults}) {
    _clearSelector();
    final completer = Completer<void>();
    _dataSourceManager.identify(context, completer,
        requireFreshData: waitForNetworkResults);
    return completer.future;
  }
}
