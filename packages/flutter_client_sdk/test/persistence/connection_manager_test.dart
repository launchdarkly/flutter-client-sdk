// ignore_for_file: close_sinks

import 'dart:async';

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_flutter_client_sdk/src/connection_manager.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class MockDestination extends Mock implements ConnectionDestination {}

class MockLogAdapter extends Mock implements LDLogAdapter {}

final class MockStateDetector implements StateDetector {
  final StreamController<ApplicationState> _applicationStateController =
      StreamController();
  final StreamController<NetworkState> _networkStateController =
      StreamController();

  ApplicationState currentApplicationState = ApplicationState.foreground;
  bool networkAvailable = true;

  late final Stream<ApplicationState> _appStateBroadcast;

  late final Stream<NetworkState> _networkStateBroadcast;

  MockStateDetector() {
    _appStateBroadcast = _applicationStateController.stream.asBroadcastStream();
    _networkStateBroadcast = _networkStateController.stream.asBroadcastStream();
  }

  @override
  Stream<ApplicationState> get applicationState => _appStateBroadcast;

  @override
  Stream<NetworkState> get networkState => _networkStateBroadcast;

  @override
  void dispose() {}

  void setApplicationState(ApplicationState state) {
    currentApplicationState = state;
    _applicationStateController.sink.add(state);
  }

  void setNetworkAvailable(bool available) {
    networkAvailable = available;
    _networkStateController.sink
        .add(available ? NetworkState.available : NetworkState.unavailable);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
    registerFallbackValue(const OfflineSetOffline());
    registerFallbackValue(const ResolvedStreaming());
  });

  test('it can set the connection offline when entering the background',
      () async {
    registerFallbackValue(ConnectionMode.streaming);

    final destination = MockDestination();
    final logAdapter = MockLogAdapter();
    final logger = LDLogger(adapter: logAdapter);
    final config = ConnectionManagerConfig(runInBackground: false);
    final mockDetector = MockStateDetector();

    final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector);

    mockDetector.setApplicationState(ApplicationState.background);

    // Wait for the state to propagate.
    await mockDetector.applicationState.first;

    verify(() => destination.setMode(
        const ResolvedOffline(OfflineBackgroundDisabled())));
    connectionManager.dispose();
  });

  group('given default connection modes', () {
    for (var initialMode in [
      ConnectionMode.streaming,
      ConnectionMode.polling,
      ConnectionMode.background,
    ]) {
      test(
          'it can restore the connection when entering the foreground for mode: $initialMode',
          () async {
        registerFallbackValue(ConnectionMode.streaming);

        final destination = MockDestination();
        final logAdapter = MockLogAdapter();
        final logger = LDLogger(adapter: logAdapter);
        final config = ConnectionManagerConfig(
            runInBackground: false, foregroundConnectionMode: initialMode);
        final mockDetector = MockStateDetector();

        final connectionManager = ConnectionManager(
            logger: logger,
            config: config,
            destination: destination,
            detector: mockDetector);

        mockDetector.setApplicationState(ApplicationState.background);

        // Wait for the state to propagate.
        await mockDetector.applicationState.first;

        verify(() => destination.setMode(
            const ResolvedOffline(OfflineBackgroundDisabled())));
        reset(destination);

        mockDetector.setApplicationState(ApplicationState.foreground);

        // Wait for the state to propagate.
        await mockDetector.applicationState.first;

        verify(() => destination.setMode(switch (initialMode) {
          ConnectionMode.streaming => const ResolvedStreaming(),
          ConnectionMode.polling => const ResolvedPolling(),
          ConnectionMode.background => const ResolvedBackground(),
          ConnectionMode.offline => const ResolvedOffline(OfflineSetOffline()),
        }));
        connectionManager.dispose();
      });
    }
  });

  test(
      'if runInBackground is true, default background slot is offline '
      '(CONNMODE §2.2.1)',
      () async {
    registerFallbackValue(ConnectionMode.streaming);

    final destination = MockDestination();
    final logAdapter = MockLogAdapter();
    final logger = LDLogger(adapter: logAdapter);
    final config = ConnectionManagerConfig(runInBackground: true);
    final mockDetector = MockStateDetector();

    final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector);

    mockDetector.setApplicationState(ApplicationState.background);

    // Wait for the state to propagate.
    await mockDetector.applicationState.first;

    verify(() => destination.flush());
    verify(() => destination.setMode(
        const ResolvedOffline(OfflineSetOffline())));
    connectionManager.dispose();
  });

  test(
      'if runInBackground is true and backgroundConnectionMode is background, '
      'it uses that slot in the background', () async {
    registerFallbackValue(ConnectionMode.streaming);
    registerFallbackValue(ConnectionMode.background);

    final destination = MockDestination();
    final logAdapter = MockLogAdapter();
    final logger = LDLogger(adapter: logAdapter);
    final config = ConnectionManagerConfig(
      runInBackground: true,
      backgroundConnectionMode: ConnectionMode.background,
    );
    final mockDetector = MockStateDetector();

    final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector);

    mockDetector.setApplicationState(ApplicationState.background);

    await mockDetector.applicationState.first;

    verify(() => destination.flush());
    verify(() => destination.setMode(const ResolvedBackground()));
    connectionManager.dispose();
  });

  test(
      'if runInBackground is true and backgroundConnectionMode is streaming, '
      'it uses that slot in the background', () async {
    registerFallbackValue(ConnectionMode.streaming);

    final destination = MockDestination();
    final logAdapter = MockLogAdapter();
    final logger = LDLogger(adapter: logAdapter);
    final config = ConnectionManagerConfig(
      runInBackground: true,
      backgroundConnectionMode: ConnectionMode.streaming,
    );
    final mockDetector = MockStateDetector();

    final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector);

    mockDetector.setApplicationState(ApplicationState.background);

    await mockDetector.applicationState.first;

    verify(() => destination.flush());
    verify(() => destination.setMode(const ResolvedStreaming()));
    connectionManager.dispose();
  });

  test(
      'it sets the network availability to false when it detects the network is not available',
      () async {
    registerFallbackValue(ConnectionMode.streaming);

    final destination = MockDestination();
    final logAdapter = MockLogAdapter();
    final logger = LDLogger(adapter: logAdapter);
    final config = ConnectionManagerConfig(runInBackground: true);
    final mockDetector = MockStateDetector();

    final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector);

    mockDetector.setNetworkAvailable(false);

    // Wait for the state to propagate.
    await mockDetector.networkState.first;

    verify(() => destination.setNetworkAvailability(false));
    verify(() => destination.setMode(
        const ResolvedOffline(OfflineNetworkUnavailable())));
    connectionManager.dispose();
  });

  test(
      'it sets the network availability to true when it detects the network is available',
      () async {
    registerFallbackValue(ConnectionMode.streaming);

    final destination = MockDestination();
    final logAdapter = MockLogAdapter();
    final logger = LDLogger(adapter: logAdapter);
    final config = ConnectionManagerConfig(runInBackground: true);
    final mockDetector = MockStateDetector();

    final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector);

    mockDetector.setNetworkAvailable(false);

    // Wait for the state to propagate.
    await mockDetector.networkState.first;

    verify(() => destination.setNetworkAvailability(false));
    reset(destination);

    mockDetector.setNetworkAvailable(true);

    // Wait for the state to propagate.
    await mockDetector.networkState.first;

    verify(() => destination.setNetworkAvailability(true));
    connectionManager.dispose();
  });

  group('network drives mode resolution and custom resolution tables', () {
    test(
        'when network is unavailable in the background, mode is offline '
        'not the background slot (first table row wins)',
        () async {
      registerFallbackValue(ConnectionMode.streaming);
      registerFallbackValue(ConnectionMode.background);

      final destination = MockDestination();
      final logAdapter = MockLogAdapter();
      final logger = LDLogger(adapter: logAdapter);
      final config = ConnectionManagerConfig(
        runInBackground: true,
        backgroundConnectionMode: ConnectionMode.background,
      );
      final mockDetector = MockStateDetector();

      final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector,
      );

      mockDetector.setApplicationState(ApplicationState.background);
      await mockDetector.applicationState.first;

      verify(() => destination.setMode(const ResolvedBackground()));
      reset(destination);

      mockDetector.setNetworkAvailable(false);
      await mockDetector.networkState.first;

      verify(() => destination.setNetworkAvailability(false));
      verify(() => destination.setMode(
          const ResolvedOffline(OfflineNetworkUnavailable())));
      connectionManager.dispose();
    });

    test(
        'when network returns while foreground, restores '
        'foregroundConnectionMode from automatic resolution',
        () async {
      registerFallbackValue(ConnectionMode.streaming);
      registerFallbackValue(ConnectionMode.polling);

      final destination = MockDestination();
      final logAdapter = MockLogAdapter();
      final logger = LDLogger(adapter: logAdapter);
      final config = ConnectionManagerConfig(
        foregroundConnectionMode: ConnectionMode.polling,
        runInBackground: true,
      );
      final mockDetector = MockStateDetector();

      final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector,
      );

      mockDetector.setNetworkAvailable(false);
      await mockDetector.networkState.first;

      verify(() => destination.setMode(
          const ResolvedOffline(OfflineNetworkUnavailable())));
      reset(destination);

      mockDetector.setNetworkAvailable(true);
      await mockDetector.networkState.first;

      verify(() => destination.setNetworkAvailability(true));
      verify(() => destination.setMode(const ResolvedPolling()));
      connectionManager.dispose();
    });

    test(
        'custom resolution table: network row only then fallback to '
        'foregroundConnectionMode when network is available',
        () async {
      registerFallbackValue(ConnectionMode.streaming);
      registerFallbackValue(ConnectionMode.polling);

      final destination = MockDestination();
      final logAdapter = MockLogAdapter();
      final logger = LDLogger(adapter: logAdapter);
      final config = ConnectionManagerConfig(
        foregroundConnectionMode: ConnectionMode.polling,
        runInBackground: true,
      );
      final mockDetector = MockStateDetector();

      final customTable = <ModeResolutionEntry>[
        ModeResolutionEntry(
          predicate: (ModeState s) => !s.networkAvailable,
          resolve: (_) =>
              const ResolvedOffline(OfflineNetworkUnavailable()),
        ),
      ];

      final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector,
        resolutionTable: customTable,
      );

      mockDetector.setNetworkAvailable(false);
      await mockDetector.networkState.first;

      verify(() => destination.setMode(
          const ResolvedOffline(OfflineNetworkUnavailable())));
      reset(destination);

      mockDetector.setNetworkAvailable(true);
      await mockDetector.networkState.first;

      verify(() => destination.setMode(const ResolvedPolling()));
      connectionManager.dispose();
    });

    test(
        'custom empty resolution table falls back to foregroundConnectionMode '
        'for all automatic states',
        () async {
      registerFallbackValue(ConnectionMode.streaming);
      registerFallbackValue(ConnectionMode.polling);

      final destination = MockDestination();
      final logAdapter = MockLogAdapter();
      final logger = LDLogger(adapter: logAdapter);
      final config = ConnectionManagerConfig(
        foregroundConnectionMode: ConnectionMode.polling,
        runInBackground: true,
      );
      final mockDetector = MockStateDetector();

      final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector,
        resolutionTable: const <ModeResolutionEntry>[],
      );

      mockDetector.setNetworkAvailable(false);
      await mockDetector.networkState.first;

      verify(() => destination.setMode(const ResolvedPolling()));
      connectionManager.dispose();
    });
  });

  test('when temporarily offline it ignores state changes and remains offline',
      () async {
    registerFallbackValue(ConnectionMode.streaming);

    final destination = MockDestination();
    final logAdapter = MockLogAdapter();
    final logger = LDLogger(adapter: logAdapter);
    final config = ConnectionManagerConfig();
    final mockDetector = MockStateDetector();

    final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector);

    connectionManager.offline = true;

    verify(() => destination.setMode(
        const ResolvedOffline(OfflineSetOffline())));
    verify(() => destination.setEventSendingEnabled(false, flush: false));
    reset(destination);

    mockDetector.setApplicationState(ApplicationState.foreground);
    mockDetector.setNetworkAvailable(true);

    // Wait for the state to propagate.
    await mockDetector.applicationState.first;
    await mockDetector.networkState.first;

    verify(() => destination.setMode(
        const ResolvedOffline(OfflineSetOffline())));
    verify(() => destination.setNetworkAvailability(true));
    verify(() => destination.setEventSendingEnabled(false, flush: false));
    connectionManager.dispose();
  });

  test(
      'if disableAutomaticBackgroundHandling is enabled, then it ignores application state changes',
      () async {
    registerFallbackValue(ConnectionMode.streaming);

    final destination = MockDestination();
    final logAdapter = MockLogAdapter();
    final logger = LDLogger(adapter: logAdapter);
    final config = ConnectionManagerConfig(
        runInBackground: false, disableAutomaticBackgroundHandling: true);
    final mockDetector = MockStateDetector();

    final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector);

    mockDetector.setApplicationState(ApplicationState.background);

    // Wait for the state to propagate.
    await mockDetector.applicationState.first;

    verifyNever(() => destination.setMode(any()));
    verifyNever(() =>
        destination.setEventSendingEnabled(any(), flush: any(named: 'flush')));
    connectionManager.dispose();
  });

  test(
      'if disableAutomaticNetworkHandling is enabled, then it ignores network state changes',
      () async {
    registerFallbackValue(ConnectionMode.streaming);

    final destination = MockDestination();
    final logAdapter = MockLogAdapter();
    final logger = LDLogger(adapter: logAdapter);
    final config = ConnectionManagerConfig(
        runInBackground: false, disableAutomaticNetworkHandling: true);
    final mockDetector = MockStateDetector();

    final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector);

    mockDetector.setNetworkAvailable(false);

    // Wait for the state to propagate.
    await mockDetector.networkState.first;

    verifyNever(() => destination.setNetworkAvailability(any()));
    verifyNever(() =>
        destination.setEventSendingEnabled(any(), flush: any(named: 'flush')));
    connectionManager.dispose();
  });

  test('setMode override: applies in background, null restores automatic table',
      () async {
    registerFallbackValue(ConnectionMode.streaming);
    registerFallbackValue(ConnectionMode.polling);

    final destination = MockDestination();
    final logAdapter = MockLogAdapter();
    final logger = LDLogger(adapter: logAdapter);
    final config = ConnectionManagerConfig(runInBackground: true);
    final mockDetector = MockStateDetector();

    final connectionManager = ConnectionManager(
        logger: logger,
        config: config,
        destination: destination,
        detector: mockDetector);

    mockDetector.setApplicationState(ApplicationState.background);
    await mockDetector.applicationState.first;

    verify(() => destination.setMode(
        const ResolvedOffline(OfflineSetOffline())));
    reset(destination);

    connectionManager.setMode(ConnectionMode.polling);
    verify(() => destination.setMode(const ResolvedPolling()));
    reset(destination);

    connectionManager.setMode(null);
    verify(() => destination.setMode(
        const ResolvedOffline(OfflineSetOffline())));
    connectionManager.dispose();
  });

  group('given requested connection modes', () {
    for (var requestedMode in [
      ConnectionMode.streaming,
      ConnectionMode.polling,
      ConnectionMode.background,
      ConnectionMode.offline,
    ]) {
      test('it respects changes to the desired connection mode', () {
        // Get an initial mode that will be different than the requested mode.
        final initialMode =
            ConnectionMode.values.firstWhere((mode) => mode != requestedMode);

        registerFallbackValue(ConnectionMode.streaming);

        final destination = MockDestination();
        final logAdapter = MockLogAdapter();
        final logger = LDLogger(adapter: logAdapter);
        final config = ConnectionManagerConfig(
            runInBackground: false, foregroundConnectionMode: initialMode);
        final mockDetector = MockStateDetector();

        final connectionManager = ConnectionManager(
            logger: logger,
            config: config,
            destination: destination,
            detector: mockDetector);

        reset(destination);
        connectionManager.setMode(requestedMode);

        verify(() => destination.setMode(switch (requestedMode) {
          ConnectionMode.streaming => const ResolvedStreaming(),
          ConnectionMode.polling => const ResolvedPolling(),
          ConnectionMode.background => const ResolvedBackground(),
          ConnectionMode.offline => const ResolvedOffline(OfflineSetOffline()),
        }));
        verifyNever(
            () => destination.setEventSendingEnabled(true, flush: false));
        connectionManager.dispose();
      });
    }
  });
}
