import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'flag_eval_mapper.dart';
import 'payload.dart';
import 'selector.dart';
import 'source.dart';
import 'source_result.dart';

/// The shape of a cache hit: parsed evaluation results plus the
/// environment ID that was current when the cache was written.
typedef CachedFlags = ({
  Map<String, LDEvaluationResult> flags,
  String? environmentId,
});

/// Reads cached flag state for [context] from persistence. Returns
/// null on a cache miss, an unreadable entry, or a parse failure.
typedef CachedFlagsReader = Future<CachedFlags?> Function(LDContext context);

/// One-shot initializer that brings the SDK up from its persistence
/// cache. The cache is read once; retries are not meaningful for a
/// local read.
///
/// On cache hit, emits a [ChangeSetResult] with `persist: false` (the
/// data came from the cache; writing it back is a no-op) and an empty
/// selector (the cache does not track server-side selector state).
/// The payload type is [PayloadType.full]: a cache load is a complete
/// snapshot, not a delta.
///
/// On cache miss, emits a [ChangeSetResult] with [PayloadType.none] so
/// the initializer chain advances rather than terminating. The cache
/// is best-effort, not a source of truth.
final class CacheInitializer implements Initializer {
  final CachedFlagsReader _reader;
  final LDContext _context;
  final LDLogger _logger;
  final DateTime Function() _now;

  bool _closed = false;

  CacheInitializer({
    required CachedFlagsReader reader,
    required LDContext context,
    required LDLogger logger,
    DateTime Function()? now,
  })  : _reader = reader,
        _context = context,
        _logger = logger.subLogger('CacheInitializer'),
        _now = now ?? DateTime.now;

  @override
  Future<FDv2SourceResult> run() async {
    if (_closed) return _shutdown();

    final CachedFlags? cached;
    try {
      cached = await _reader(_context);
    } catch (err) {
      _logger.warn('Cache read failed (${err.runtimeType}); '
          'treating as miss');
      return _miss();
    }

    if (_closed) return _shutdown();

    if (cached == null) {
      return _miss();
    }

    final updates = <Update>[];
    cached.flags.forEach((key, evalResult) {
      updates.add(Update(
        kind: flagEvalKind,
        key: key,
        version: evalResult.version,
        object: LDEvaluationResultSerialization.toJson(evalResult),
      ));
    });

    return ChangeSetResult(
      payload: Payload(
        type: PayloadType.full,
        selector: Selector.empty,
        updates: updates,
      ),
      environmentId: cached.environmentId,
      freshness: _now(),
      persist: false,
    );
  }

  @override
  void close() {
    _closed = true;
  }

  ChangeSetResult _miss() => ChangeSetResult(
        payload: const Payload(
          type: PayloadType.none,
          updates: [],
        ),
        freshness: _now(),
        persist: false,
      );

  StatusResult _shutdown() => FDv2SourceResults.shutdown(
        message: 'Cache initializer closed before completion',
      );
}
