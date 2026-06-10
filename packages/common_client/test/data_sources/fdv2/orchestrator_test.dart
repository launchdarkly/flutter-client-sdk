import 'dart:async';
import 'dart:io';

import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/entry_factories.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/orchestrator.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

final class FakeInitializer implements Initializer {
  final FDv2SourceResult result;
  bool closed = false;
  int runCount = 0;

  FakeInitializer(this.result);

  @override
  Future<FDv2SourceResult> run() async {
    runCount += 1;
    return result;
  }

  @override
  void close() {
    closed = true;
  }
}

final class FakeSynchronizer implements Synchronizer {
  final StreamController<FDv2SourceResult> controller =
      StreamController<FDv2SourceResult>();
  bool closed = false;

  @override
  Stream<FDv2SourceResult> get results => controller.stream;

  @override
  void close() {
    closed = true;
    if (!controller.isClosed) {
      controller.close();
    }
  }
}

InitializerFactory initializerFactory(FDv2SourceResult result,
    {bool isCache = false, List<FakeInitializer>? created}) {
  return InitializerFactory(
    isCache: isCache,
    create: (_) {
      final initializer = FakeInitializer(result);
      created?.add(initializer);
      return initializer;
    },
  );
}

SynchronizerSlot synchronizerSlot(List<FakeSynchronizer> created,
    {bool isFdv1Fallback = false}) {
  return SynchronizerSlot(
    isFdv1Fallback: isFdv1Fallback,
    factory: SynchronizerFactory(create: (_) {
      final synchronizer = FakeSynchronizer();
      created.add(synchronizer);
      return synchronizer;
    }),
  );
}

ChangeSetResult changeSet({
  Selector selector = Selector.empty,
  PayloadType type = PayloadType.full,
  bool fdv1Fallback = false,
}) {
  return ChangeSetResult(
    payload: Payload(selector: selector, type: type, updates: const []),
    persist: true,
    fdv1Fallback: fdv1Fallback,
  );
}

final class Harness {
  final List<DataSourceEvent> events = [];
  final List<Selector> selectorUpdates = [];
  Selector selector = Selector.empty;
  late final FDv2DataSourceOrchestrator orchestrator;
  late final StreamSubscription<DataSourceEvent> subscription;

  Harness({
    required List<InitializerFactory> initializerFactories,
    required List<SynchronizerSlot> synchronizerSlots,
    Duration fallbackTimeout = const Duration(seconds: 120),
    Duration recoveryTimeout = const Duration(seconds: 300),
  }) {
    orchestrator = FDv2DataSourceOrchestrator(
      initializerFactories: initializerFactories,
      synchronizerSlots: synchronizerSlots,
      selectorGetter: () => selector,
      selectorUpdater: (updated) {
        selector = updated;
        selectorUpdates.add(updated);
      },
      statusManager: DataSourceStatusManager(),
      logger: LDLogger(level: LDLogLevel.none),
      fallbackTimeout: fallbackTimeout,
      recoveryTimeout: recoveryTimeout,
      recycleDelay: Duration.zero,
    );
    subscription = orchestrator.events.listen(events.add);
  }

  Future<void> pump([int times = 8]) async {
    for (var i = 0; i < times; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  test('runs initializers in order until one returns basis data', () async {
    final firstCreated = <FakeInitializer>[];
    final secondCreated = <FakeInitializer>[];
    final thirdCreated = <FakeInitializer>[];
    final synchronizers = <FakeSynchronizer>[];

    final harness = Harness(initializerFactories: [
      initializerFactory(FDv2SourceResults.interrupted(message: 'down'),
          created: firstCreated),
      initializerFactory(
          changeSet(selector: const Selector(state: 'state-1', version: 1)),
          created: secondCreated),
      initializerFactory(changeSet(), created: thirdCreated),
    ], synchronizerSlots: [
      synchronizerSlot(synchronizers),
    ]);

    harness.orchestrator.start();
    await harness.pump();

    expect(firstCreated.single.runCount, 1);
    expect(secondCreated.single.runCount, 1);
    expect(thirdCreated, isEmpty,
        reason: 'a payload with a selector completes initialization');
    expect(harness.events.whereType<PayloadEvent>(), hasLength(1));
    expect(harness.selector.state, 'state-1');
    expect(synchronizers, hasLength(1),
        reason: 'the synchronizer tier starts after initialization');

    harness.orchestrator.stop();
  });

  test('skips data-less results from initializers and keeps going', () async {
    final synchronizers = <FakeSynchronizer>[];
    final harness = Harness(initializerFactories: [
      initializerFactory(changeSet(type: PayloadType.none), isCache: true),
      initializerFactory(
          changeSet(selector: const Selector(state: 'state-1', version: 1))),
    ], synchronizerSlots: [
      synchronizerSlot(synchronizers),
    ]);

    harness.orchestrator.start();
    await harness.pump();

    final payloads = harness.events.whereType<PayloadEvent>().toList();
    expect(payloads, hasLength(1),
        reason: 'the cache miss payload is not emitted');
    expect(payloads.single.payload.selector.state, 'state-1');

    harness.orchestrator.stop();
  });

  test(
      'cache-only data system emits an empty payload on a miss so the SDK '
      'reaches a usable state', () async {
    final harness = Harness(initializerFactories: [
      initializerFactory(changeSet(type: PayloadType.none), isCache: true),
    ], synchronizerSlots: []);

    harness.orchestrator.start();
    await harness.pump();

    final payloads = harness.events.whereType<PayloadEvent>().toList();
    expect(payloads, hasLength(1));
    expect(payloads.single.payload.type, PayloadType.none);

    harness.orchestrator.stop();
  });

  test('synchronizer change sets are emitted and update the selector',
      () async {
    final synchronizers = <FakeSynchronizer>[];
    final harness = Harness(
      initializerFactories: [],
      synchronizerSlots: [synchronizerSlot(synchronizers)],
    );

    harness.orchestrator.start();
    await harness.pump();

    synchronizers.single.controller
        .add(changeSet(selector: const Selector(state: 'state-2', version: 2)));
    await harness.pump();

    expect(harness.events.whereType<PayloadEvent>(), hasLength(1));
    expect(harness.selector.state, 'state-2');

    harness.orchestrator.stop();
  });

  test('a payload of type none does not regress the held selector', () async {
    final synchronizers = <FakeSynchronizer>[];
    final harness = Harness(
      initializerFactories: [],
      synchronizerSlots: [synchronizerSlot(synchronizers)],
    );
    harness.selector = const Selector(state: 'held', version: 7);

    harness.orchestrator.start();
    await harness.pump();
    synchronizers.single.controller.add(changeSet(type: PayloadType.none));
    await harness.pump();

    expect(harness.selector.state, 'held');
    expect(harness.events.whereType<PayloadEvent>(), hasLength(1),
        reason: 'the up-to-date payload still flows through the pipeline');

    harness.orchestrator.stop();
  });

  test('terminal error blocks the synchronizer and advances to the next',
      () async {
    final firstTier = <FakeSynchronizer>[];
    final secondTier = <FakeSynchronizer>[];
    final harness = Harness(
      initializerFactories: [],
      synchronizerSlots: [
        synchronizerSlot(firstTier),
        synchronizerSlot(secondTier),
      ],
    );

    harness.orchestrator.start();
    await harness.pump();

    firstTier.single.controller
        .add(FDv2SourceResults.terminalError(message: 'denied'));
    await harness.pump();

    expect(secondTier, hasLength(1));
    secondTier.single.controller
        .add(changeSet(selector: const Selector(state: 's', version: 1)));
    await harness.pump();

    expect(harness.events.whereType<PayloadEvent>(), hasLength(1));

    harness.orchestrator.stop();
  });

  test('goodbye re-establishes the same synchronizer', () async {
    final synchronizers = <FakeSynchronizer>[];
    final harness = Harness(
      initializerFactories: [],
      synchronizerSlots: [synchronizerSlot(synchronizers)],
    );

    harness.orchestrator.start();
    await harness.pump();

    synchronizers.single.controller
        .add(FDv2SourceResults.goodbyeResult(message: 'bye'));
    await harness.pump();

    expect(synchronizers, hasLength(2),
        reason: 'a fresh instance of the same slot is created');
    expect(synchronizers.first.closed, isTrue);

    harness.orchestrator.stop();
  });

  test('restart re-establishes the active synchronizer', () async {
    final synchronizers = <FakeSynchronizer>[];
    final harness = Harness(
      initializerFactories: [],
      synchronizerSlots: [synchronizerSlot(synchronizers)],
    );

    harness.orchestrator.start();
    await harness.pump();

    harness.orchestrator.restart();
    await harness.pump();

    expect(synchronizers, hasLength(2));
    expect(synchronizers.first.closed, isTrue);

    harness.orchestrator.stop();
  });

  test(
      'halts with a shutdown status when every source is exhausted without '
      'data', () async {
    final synchronizers = <FakeSynchronizer>[];
    final harness = Harness(
      initializerFactories: [
        initializerFactory(FDv2SourceResults.interrupted(message: 'down')),
      ],
      synchronizerSlots: [synchronizerSlot(synchronizers)],
    );

    harness.orchestrator.start();
    await harness.pump();

    synchronizers.single.controller
        .add(FDv2SourceResults.terminalError(message: 'denied'));
    await harness.pump();

    final statuses = harness.events.whereType<StatusEvent>().toList();
    expect(statuses, hasLength(1));
    expect(statuses.single.shutdown, isTrue);
    expect(statuses.single.kind, ErrorKind.unknown);

    harness.orchestrator.stop();
  });

  test(
      'an FDv1 fallback directive engages the fallback slot and blocks the '
      'FDv2 synchronizers', () async {
    final fdv2Tier = <FakeSynchronizer>[];
    final fdv1Tier = <FakeSynchronizer>[];
    final harness = Harness(
      initializerFactories: [],
      synchronizerSlots: [
        synchronizerSlot(fdv2Tier),
        synchronizerSlot(fdv1Tier, isFdv1Fallback: true),
      ],
    );

    harness.orchestrator.start();
    await harness.pump();

    expect(fdv1Tier, isEmpty, reason: 'the FDv1 slot starts blocked');

    fdv2Tier.single.controller.add(FDv2SourceResults.terminalError(
        message: 'fall back', fdv1Fallback: true));
    await harness.pump();

    expect(fdv1Tier, hasLength(1));

    harness.orchestrator.stop();
  });

  test('stop closes the active synchronizer and ends the loop', () async {
    final synchronizers = <FakeSynchronizer>[];
    final harness = Harness(
      initializerFactories: [],
      synchronizerSlots: [synchronizerSlot(synchronizers)],
    );

    harness.orchestrator.start();
    await harness.pump();

    harness.orchestrator.stop();
    await harness.pump();

    expect(synchronizers.single.closed, isTrue);
    expect(synchronizers, hasLength(1),
        reason: 'no replacement source is created after stop');
  });

  test('memory stays bounded while a healthy synchronizer streams results',
      () async {
    // A healthy primary that streams change sets indefinitely is the
    // steady state of a stable connection. Consumption must not attach
    // anything per-result to long-lived futures or streams: listeners
    // on a never-completing future cannot be removed, so a per-result
    // attachment grows for the synchronizer's entire tenure
    // (measured at roughly 3 KB per result before consumption became
    // subscription-driven, roughly 100 MB over this soak).
    Future<int> soak(FakeSynchronizer synchronizer, int results) async {
      const healthyResult = ChangeSetResult(
          payload: Payload(type: PayloadType.partial, updates: []),
          persist: true);
      final baseline = ProcessInfo.currentRss;
      for (var i = 0; i < results; i++) {
        synchronizer.controller.add(healthyResult);
        await Future<void>.delayed(Duration.zero);
      }
      return ProcessInfo.currentRss - baseline;
    }

    // Two slots so the primary carries a fallback condition; this is
    // the configuration with the most per-result machinery. The
    // orchestrator is constructed directly so the emitted payload
    // events can be discarded instead of retained.
    final synchronizers = <FakeSynchronizer>[];
    final orchestrator = FDv2DataSourceOrchestrator(
      initializerFactories: const [],
      synchronizerSlots: [
        synchronizerSlot(synchronizers),
        synchronizerSlot(synchronizers),
      ],
      selectorGetter: () => Selector.empty,
      selectorUpdater: (_) {},
      statusManager: DataSourceStatusManager(),
      logger: LDLogger(level: LDLogLevel.none),
    );
    final subscription = orchestrator.events.listen((_) {});
    orchestrator.start();
    await Future<void>.delayed(Duration.zero);

    // Warm up allocators before measuring.
    await soak(synchronizers.single, 2000);
    final growth = await soak(synchronizers.single, 30000);

    expect(growth, lessThan(25 * 1024 * 1024),
        reason: 'memory grew ${(growth / 1024 / 1024).toStringAsFixed(1)} MB '
            'over 30000 results; per-result state is accumulating');

    orchestrator.stop();
    await subscription.cancel();
  });
}
