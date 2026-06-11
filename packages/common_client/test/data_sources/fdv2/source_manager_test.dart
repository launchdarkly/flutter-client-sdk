import 'dart:async';

import 'package:launchdarkly_common_client/src/data_sources/fdv2/entry_factories.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:test/test.dart';

final class RecordingInitializer implements Initializer {
  bool closed = false;

  @override
  Future<FDv2SourceResult> run() async =>
      FDv2SourceResults.shutdown(message: 'unused');

  @override
  void close() {
    closed = true;
  }
}

final class RecordingSynchronizer implements Synchronizer {
  final int slotIndex;
  bool closed = false;

  RecordingSynchronizer(this.slotIndex);

  @override
  Stream<FDv2SourceResult> get results => const Stream.empty();

  @override
  void close() {
    closed = true;
  }
}

SynchronizerSlot _slot(int index, List<RecordingSynchronizer> created,
    {bool isFdv1Fallback = false}) {
  return SynchronizerSlot(
    isFdv1Fallback: isFdv1Fallback,
    factory: SynchronizerFactory(create: (_) {
      final synchronizer = RecordingSynchronizer(index);
      created.add(synchronizer);
      return synchronizer;
    }),
  );
}

SourceManager _manager(
    {List<InitializerFactory> initializers = const [],
    List<SynchronizerSlot> slots = const []}) {
  return SourceManager(
    initializerFactories: initializers,
    synchronizerSlots: slots,
    selectorGetter: () => Selector.empty,
  );
}

void main() {
  test('initializers are produced once each, in order, and exhaust', () {
    final created = <RecordingInitializer>[];
    InitializerFactory factory() => InitializerFactory(create: (_) {
          final initializer = RecordingInitializer();
          created.add(initializer);
          return initializer;
        });

    final manager = _manager(initializers: [factory(), factory()]);

    expect(manager.nextInitializer(), isNotNull);
    expect(manager.nextInitializer(), isNotNull);
    expect(manager.nextInitializer(), isNull);
    expect(created, hasLength(2));
    expect(created.first.closed, isTrue,
        reason: 'starting the second source closes the first');
  });

  test('synchronizers cycle through available slots and wrap around', () {
    final created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [_slot(0, created), _slot(1, created)]);

    expect(manager.nextAvailableSynchronizer(), isNotNull);
    expect(created.last.slotIndex, 0);
    expect(manager.isPrimarySynchronizer, isTrue);

    expect(manager.nextAvailableSynchronizer(), isNotNull);
    expect(created.last.slotIndex, 1);
    expect(manager.isPrimarySynchronizer, isFalse);

    expect(manager.nextAvailableSynchronizer(), isNotNull);
    expect(created.last.slotIndex, 0, reason: 'cycling wraps to the start');
  });

  test('a blocked slot is skipped', () {
    final created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [_slot(0, created), _slot(1, created)]);

    manager.nextAvailableSynchronizer();
    manager.blockCurrentSynchronizer();
    expect(manager.availableSynchronizerCount, 1);

    manager.nextAvailableSynchronizer();
    expect(created.last.slotIndex, 1);
    manager.nextAvailableSynchronizer();
    expect(created.last.slotIndex, 1,
        reason: 'only the unblocked slot remains in rotation');
  });

  test('all slots blocked yields null', () {
    final created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [_slot(0, created)]);

    manager.nextAvailableSynchronizer();
    manager.blockCurrentSynchronizer();
    expect(manager.nextAvailableSynchronizer(), isNull);
  });

  test('resetSynchronizerIndex returns rotation to the first slot', () {
    final created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [_slot(0, created), _slot(1, created)]);

    manager.nextAvailableSynchronizer();
    manager.nextAvailableSynchronizer();
    manager.resetSynchronizerIndex();
    manager.nextAvailableSynchronizer();
    expect(created.last.slotIndex, 0);
  });

  test(
      'recreateCurrentSynchronizer produces a fresh instance of the same '
      'slot', () {
    final created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [_slot(0, created), _slot(1, created)]);

    manager.nextAvailableSynchronizer();
    final recreated = manager.recreateCurrentSynchronizer();
    expect(recreated, isNotNull);
    expect(created, hasLength(2));
    expect(created.last.slotIndex, 0);
    expect(created.first.closed, isTrue);
    expect(manager.isPrimarySynchronizer, isTrue);
  });

  test('FDv1 fallback slots start blocked and engage on fallback', () {
    final fdv2Created = <RecordingSynchronizer>[];
    final fdv1Created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [
      _slot(0, fdv2Created),
      _slot(1, fdv1Created, isFdv1Fallback: true),
    ]);

    expect(manager.hasFdv1Fallback, isTrue);
    expect(manager.availableSynchronizerCount, 1);

    manager.nextAvailableSynchronizer();
    expect(fdv2Created, hasLength(1));

    manager.engageFdv1Fallback();
    expect(manager.availableSynchronizerCount, 1);

    manager.nextAvailableSynchronizer();
    expect(fdv1Created, hasLength(1));
    expect(fdv2Created, hasLength(1),
        reason: 'the FDv2 tier is disabled after fallback');
  });

  test('close prevents further source creation', () {
    final created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [_slot(0, created)]);

    manager.nextAvailableSynchronizer();
    manager.close();
    expect(manager.isShutdown, isTrue);
    expect(created.single.closed, isTrue);
    expect(manager.nextAvailableSynchronizer(), isNull);
    expect(manager.recreateCurrentSynchronizer(), isNull);
  });
}
