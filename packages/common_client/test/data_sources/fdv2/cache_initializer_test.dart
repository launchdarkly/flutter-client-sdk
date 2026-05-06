import 'package:launchdarkly_common_client/src/data_sources/fdv2/cache_initializer.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

LDEvaluationResult _evalResult({int version = 1, bool value = true}) =>
    LDEvaluationResult(
      version: version,
      detail: LDEvaluationDetail<LDValue>(
          value ? LDValue.ofBool(true) : LDValue.ofBool(false), 0, null),
    );

LDContext _ctx() => LDContextBuilder().kind('user', 'alice').build();

CachedFlagsReader _staticReader(CachedFlags? value) =>
    (LDContext _) async => value;

CachedFlagsReader _throwingReader(Object error) => (LDContext _) async {
      throw error;
    };

void main() {
  final logger = LDLogger(level: LDLogLevel.error);

  test('cache hit emits a full ChangeSetResult with updates and persist=false',
      () async {
    final init = CacheInitializer(
      reader: _staticReader((
        flags: {
          'flag-a': _evalResult(version: 7),
          'flag-b': _evalResult(version: 9, value: false),
        },
        environmentId: 'env-xyz',
      )),
      context: _ctx(),
      logger: logger,
    );

    final result = await init.run();

    expect(result, isA<ChangeSetResult>());
    final cs = result as ChangeSetResult;
    expect(cs.persist, isFalse);
    expect(cs.payload.type, equals(PayloadType.full));
    expect(cs.payload.selector.isEmpty, isTrue);
    expect(cs.environmentId, equals('env-xyz'));
    expect(cs.payload.updates, hasLength(2));

    final byKey = {for (final u in cs.payload.updates) u.key: u};
    expect(byKey['flag-a']?.version, equals(7));
    expect(byKey['flag-a']?.kind, equals('flag-eval'));
    expect(byKey['flag-a']?.deleted, isFalse);
    expect(byKey['flag-a']?.object, isNotNull);
    expect(byKey['flag-b']?.version, equals(9));
  });

  test('cache hit Updates round-trip through LDEvaluationResultSerialization',
      () async {
    // Confirms the cache initializer writes the same JSON shape that the
    // protocol handler's flag_eval mapper expects on the read side.
    final original = _evalResult(version: 42);
    final init = CacheInitializer(
      reader: _staticReader((flags: {'k': original}, environmentId: null)),
      context: _ctx(),
      logger: logger,
    );

    final result = await init.run();
    final cs = result as ChangeSetResult;
    final update = cs.payload.updates.single;

    final reconstructed =
        LDEvaluationResultSerialization.fromJson(update.object!);
    expect(reconstructed, equals(original));
  });

  test('cache miss emits a none-type ChangeSetResult so the chain advances',
      () async {
    final init = CacheInitializer(
      reader: _staticReader(null),
      context: _ctx(),
      logger: logger,
    );

    final result = await init.run();

    expect(result, isA<ChangeSetResult>());
    final cs = result as ChangeSetResult;
    expect(cs.payload.type, equals(PayloadType.none));
    expect(cs.payload.updates, isEmpty);
    expect(cs.persist, isFalse);
    expect(cs.environmentId, isNull);
  });

  test('reader throws is treated as a cache miss (does not propagate)',
      () async {
    final init = CacheInitializer(
      reader: _throwingReader(StateError('persistence corrupt')),
      context: _ctx(),
      logger: logger,
    );

    final result = await init.run();

    expect(result, isA<ChangeSetResult>());
    expect((result as ChangeSetResult).payload.type, equals(PayloadType.none));
  });

  test('close before run returns shutdown without invoking reader', () async {
    var readerCalled = false;
    final init = CacheInitializer(
      reader: (LDContext _) async {
        readerCalled = true;
        return null;
      },
      context: _ctx(),
      logger: logger,
    );
    init.close();

    final result = await init.run();

    expect((result as StatusResult).state, equals(SourceState.shutdown));
    expect(readerCalled, isFalse);
  });

  test('close is idempotent', () {
    final init = CacheInitializer(
      reader: _staticReader(null),
      context: _ctx(),
      logger: logger,
    );
    init.close();
    expect(() => init.close(), returnsNormally);
  });

  test('freshness is set from the now function', () async {
    final fixedNow = DateTime.utc(2026, 4, 28, 15, 30);
    final init = CacheInitializer(
      reader: _staticReader(
          (flags: <String, LDEvaluationResult>{}, environmentId: null)),
      context: _ctx(),
      logger: logger,
      now: () => fixedNow,
    );

    final result = await init.run();
    expect((result as ChangeSetResult).freshness, equals(fixedNow));
  });
}
