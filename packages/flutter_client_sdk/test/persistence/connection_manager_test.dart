import 'dart:async';

import 'package:launchdarkly_common_client/ld_common_client.dart';
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

    verify(() => destination.setMode(ConnectionMode.offline));
    connectionManager.dispose();
  });

  group('given default connection modes', () {
    for (var initialMode in [
      ConnectionMode.streaming,
      ConnectionMode.polling
    ]) {
      test(
          'it can restore the connection when entering the foreground for mode: $initialMode',
          () async {
        registerFallbackValue(ConnectionMode.streaming);

        final destination = MockDestination();
        final logAdapter = MockLogAdapter();
        final logger = LDLogger(adapter: logAdapter);
        final config = ConnectionManagerConfig(
            runInBackground: false, initialConnectionMode: initialMode);
        final mockDetector = MockStateDetector();

        final connectionManager = ConnectionManager(
            logger: logger,
            config: config,
            destination: destination,
            detector: mockDetector);

        mockDetector.setApplicationState(ApplicationState.background);

        // Wait for the state to propagate.
        await mockDetector.applicationState.first;

        verify(() => destination.setMode(ConnectionMode.offline));
        reset(destination);

        mockDetector.setApplicationState(ApplicationState.foreground);

        // Wait for the state to propagate.
        await mockDetector.applicationState.first;

        verify(() => destination.setMode(initialMode));
        connectionManager.dispose();
      });
    }
  });

  test(
      'if runInBackground is true, then it remains online when entering the background',
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

    verify(() => destination.setMode(ConnectionMode.streaming));
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

    verify(() => destination.setMode(ConnectionMode.offline));
    verify(() => destination.setEventSendingEnabled(false, flush: false));
    reset(destination);

    mockDetector.setApplicationState(ApplicationState.foreground);
    mockDetector.setNetworkAvailable(true);

    // Wait for the state to propagate.
    await mockDetector.applicationState.first;
    await mockDetector.networkState.first;

    verify(() => destination.setMode(ConnectionMode.offline));
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

  group('given requested connection modes', () {
    for (var requestedMode in [
      ConnectionMode.streaming,
      ConnectionMode.polling,
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
            runInBackground: false, initialConnectionMode: initialMode);
        final mockDetector = MockStateDetector();

        final connectionManager = ConnectionManager(
            logger: logger,
            config: config,
            destination: destination,
            detector: mockDetector);

        reset(destination);
        connectionManager.setMode(requestedMode);

        verify(() => destination.setMode(requestedMode));
        verifyNever(
            () => destination.setEventSendingEnabled(true, flush: false));
        connectionManager.dispose();
      });
    }
  });
}
