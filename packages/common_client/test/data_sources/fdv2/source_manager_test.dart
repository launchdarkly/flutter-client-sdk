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
    // Three slots: without the reset the third request would produce
    // slot 2, so this fails if resetSynchronizerIndex does nothing.
    final manager = _manager(
        slots: [_slot(0, created), _slot(1, created), _slot(2, created)]);

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

    expect(manager.hasFdv1FallbackConfigured, isTrue);
    expect(manager.availableSynchronizerCount, 1);

    manager.nextAvailableSynchronizer();
    expect(fdv2Created, hasLength(1));

    manager.engageFdv1Fallback();
    expect(manager.availableSynchronizerCount, 1);
    expect(fdv2Created.single.closed, isTrue,
        reason: 'fallback must not leave the FDv2 source running');

    manager.nextAvailableSynchronizer();
    expect(fdv1Created, hasLength(1));
    expect(fdv2Created, hasLength(1),
        reason: 'the FDv2 tier is disabled after fallback');
  });

  test('engageFdv1Fallback has no effect without a configured FDv1 slot', () {
    final created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [_slot(0, created)]);

    manager.nextAvailableSynchronizer();
    manager.engageFdv1Fallback();

    expect(created.single.closed, isFalse);
    expect(manager.availableSynchronizerCount, 1,
        reason: 'a fallback directive must not be able to leave the SDK '
            'with no usable synchronizer tier');
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

  test('isPrimarySynchronizer is false when no synchronizer is active', () {
    final created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [_slot(0, created)]);

    expect(manager.isPrimarySynchronizer, isFalse,
        reason: 'nothing has been produced yet');

    manager.nextAvailableSynchronizer();
    expect(manager.isPrimarySynchronizer, isTrue);

    manager.blockCurrentSynchronizer();
    manager.resetSynchronizerIndex();
    expect(manager.isPrimarySynchronizer, isFalse,
        reason: 'the active slot is blocked, so it cannot be the first '
            'available');
  });

  test('blockCurrentSynchronizer blocks the active slot after a reset', () {
    final created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [_slot(0, created), _slot(1, created)]);

    manager.nextAvailableSynchronizer();
    manager.resetSynchronizerIndex();
    manager.blockCurrentSynchronizer();

    expect(manager.availableSynchronizerCount, 1,
        reason: 'blocking applies to the active source, not the scan '
            'cursor');
    manager.nextAvailableSynchronizer();
    expect(created.last.slotIndex, 1);
  });

  test('exhausting the initializers closes the last initializer', () {
    final created = <RecordingInitializer>[];
    final manager = _manager(initializers: [
      InitializerFactory(create: (_) {
        final initializer = RecordingInitializer();
        created.add(initializer);
        return initializer;
      })
    ]);

    manager.nextInitializer();
    expect(created.single.closed, isFalse);

    expect(manager.nextInitializer(), isNull);
    expect(created.single.closed, isTrue,
        reason: 'a terminal null leaves no source running');
  });

  test('starting a synchronizer closes the active initializer', () {
    final initializers = <RecordingInitializer>[];
    final synchronizers = <RecordingSynchronizer>[];
    final manager = _manager(initializers: [
      InitializerFactory(create: (_) {
        final initializer = RecordingInitializer();
        initializers.add(initializer);
        return initializer;
      })
    ], slots: [
      _slot(0, synchronizers)
    ]);

    manager.nextInitializer();
    manager.nextAvailableSynchronizer();
    expect(initializers.single.closed, isTrue);
  });

  test('nextInitializer after close returns null', () {
    final created = <RecordingInitializer>[];
    final manager = _manager(initializers: [
      InitializerFactory(create: (_) {
        final initializer = RecordingInitializer();
        created.add(initializer);
        return initializer;
      })
    ]);

    manager.close();
    expect(manager.nextInitializer(), isNull);
    expect(created, isEmpty);
  });

  test('recreateCurrentSynchronizer returns null when the slot is blocked', () {
    final created = <RecordingSynchronizer>[];
    final manager = _manager(slots: [_slot(0, created)]);

    manager.nextAvailableSynchronizer();
    manager.blockCurrentSynchronizer();
    expect(manager.recreateCurrentSynchronizer(), isNull);
    expect(created, hasLength(1));
  });
}
