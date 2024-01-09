import 'package:launchdarkly_dart_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_status_manager.dart';
import 'package:test/test.dart';

void main() {
  group('given a manager with incrementing time', () {
    DataSourceStatusManager? manager;
    setUp(() {
      var time = 0;
      manager = DataSourceStatusManager(stamper: () {
        time++;
        return DateTime(time);
      });
    });

    test('it defaults to initializing', () {
      final status = manager!.status;
      expect(status.state, DataSourceState.initializing);
      expect(status.lastError, isNull);
      expect(status.stateSince, DateTime(1));
    });

    tearDown(() => manager!.stop());

    group('given transitions from initializing', () {
      final vectors = [
        [
          (DataSourceStatusManager manager) => manager.setValid(),
          DataSourceState.valid
        ],
        [
          (DataSourceStatusManager manager) => manager.setOffline(),
          DataSourceState.setOffline
        ],
        [
          (DataSourceStatusManager manager) => manager.setNetworkUnavailable(),
          DataSourceState.networkUnavailable
        ],
      ];
      for (var vector in vectors) {
        final transition = vector[0] as Function(DataSourceStatusManager);
        final state = vector[1] as DataSourceState;

        test('it can transition from initializing to valid states: $state', () {
          transition(manager!);
          final status = manager!.status;
          expect(status.state, state);
        });

        test('it emits events on state transition: $state', () {
          expectLater(manager!.changes,
              emits(DataSourceStatus(state: state, stateSince: DateTime(2))));
          transition(manager!);
        });

        test('it does not emit on transition to same state without error', () {
          transition(manager!);
          expectLater(manager!.changes, neverEmits(anything));
          transition(manager!);
          // We close the manager early here to allow the closed to happen for
          // the expect later.
          manager!.stop();
        });

        test('states other than initializing transfer to interrupted', () {
          transition(manager!);
          manager!.setErrorByKind(ErrorKind.networkError, 'bad network');
          final status = manager!.status;
          expect(status.state, DataSourceState.interrupted);
        });
      }
    });

    test(
        'initializing does not transition to interrupted via an error response',
        () {
      manager!.setErrorResponse(503, 'why?');
      final status = manager!.status;
      expect(status.state, DataSourceState.initializing);
      expect(status.stateSince, DateTime(1));
    });

    test('initializing does not transition to interrupted via a generic error',
        () {
      manager!.setErrorByKind(ErrorKind.networkError, 'bad network');
      final status = manager!.status;
      expect(status.state, DataSourceState.initializing);
      expect(status.stateSince, DateTime(1));
    });

    test('a terminal error transition will shutdown', () {
      manager!.setErrorResponse(404, 'why?', shutdown: true);
      final status = manager!.status;
      expect(status.state, DataSourceState.shutdown);
      expect(status.stateSince, DateTime(3));
    });

    test('it records error information for an error response', () {
      manager!.setErrorResponse(503, 'the message');
      final status = manager!.status;
      expect(status.lastError!.statusCode, 503);
      expect(status.lastError!.message, 'the message');
      expect(status.lastError!.time, DateTime(2));
    });

    test('it records error information for a generic error', () {
      manager!.setErrorByKind(ErrorKind.networkError, 'bad network');
      final status = manager!.status;
      expect(status.lastError!.statusCode, isNull);
      expect(status.lastError!.message, 'bad network');
      expect(status.lastError!.time, DateTime(2));
    });

    test('it emits changes for errors', () {
      expectLater(
          manager!.changes,
          emits(DataSourceStatus(
              state: DataSourceState.initializing,
              stateSince: DateTime(1),
              lastError: DataSourceStatusErrorInfo(
                  kind: ErrorKind.networkError,
                  message: 'bad network',
                  time: DateTime(2),
                  statusCode: null))));
      manager!.setErrorByKind(ErrorKind.networkError, 'bad network');
    });
  });
}
