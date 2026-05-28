import 'package:fake_async/fake_async.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/state_debounce_manager.dart';
import 'package:launchdarkly_common_client/src/fdv2_connection_mode.dart';
import 'package:test/test.dart';

const _initial = DebouncedState(
  networkAvailable: true,
  inForeground: true,
  requestedMode: null,
);

const _debounceWindow = Duration(seconds: 1);

void main() {
  group('default window', () {
    test('does not fire when state never changes', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
          onReconcile: calls.add,
        );

        manager.setNetworkAvailable(true);
        manager.setInForeground(true);

        async.elapse(const Duration(seconds: 5));
        expect(calls, isEmpty);
        manager.close();
      });
    });

    test('fires once after the window closes following a single change', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
          onReconcile: calls.add,
        );

        manager.setNetworkAvailable(false);
        async.elapse(_debounceWindow);

        expect(calls, hasLength(1));
        expect(calls.single.networkAvailable, isFalse);
        manager.close();
      });
    });

    test('rapid changes reset the timer; one fire after final quiet', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
          onReconcile: calls.add,
        );

        manager.setNetworkAvailable(false);
        async.elapse(const Duration(milliseconds: 500));
        manager.setNetworkAvailable(true);
        async.elapse(const Duration(milliseconds: 500));
        manager.setNetworkAvailable(false);
        async.elapse(const Duration(milliseconds: 500));

        expect(calls, isEmpty);

        async.elapse(_debounceWindow);
        expect(calls, hasLength(1));
        expect(calls.single.networkAvailable, isFalse);
        manager.close();
      });
    });

    test('flap-and-return fires the resolved (matching-actual) state', () {
      // Spec 3.5 example 1: starting from {online,...}, network flaps offline
      // and back to online; resolved state matches the starting actual state.
      // The debouncer still fires (its job is to deliver the resolved tuple);
      // the consumer is responsible for the no-op-if-no-change check.
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
          onReconcile: calls.add,
        );

        manager.setNetworkAvailable(false);
        manager.setNetworkAvailable(true);
        manager.setNetworkAvailable(false);
        manager.setNetworkAvailable(true);

        async.elapse(_debounceWindow);
        expect(calls, hasLength(1));
        expect(calls.single.networkAvailable, isTrue);
        manager.close();
      });
    });

    test('combined lifecycle + network change fires a single reconcile', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
          onReconcile: calls.add,
        );

        manager.setNetworkAvailable(false);
        async.elapse(const Duration(milliseconds: 100));
        manager.setInForeground(false);

        async.elapse(_debounceWindow);
        expect(calls, hasLength(1));
        expect(calls.single.networkAvailable, isFalse);
        expect(calls.single.inForeground, isFalse);
        manager.close();
      });
    });

    test('requested mode change debounces along with the other axes', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
          onReconcile: calls.add,
        );

        manager.setRequestedMode(const FDv2Polling());
        async.elapse(_debounceWindow);

        expect(calls, hasLength(1));
        expect(calls.single.requestedMode, const FDv2Polling());
        manager.close();
      });
    });

    test('close cancels a pending timer', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
          onReconcile: calls.add,
        );

        manager.setNetworkAvailable(false);
        manager.close();

        async.elapse(const Duration(seconds: 5));
        expect(calls, isEmpty);
      });
    });

    test('setters after close do not schedule a new fire', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
          onReconcile: calls.add,
        );

        manager.close();
        manager.setNetworkAvailable(false);
        manager.setInForeground(false);
        manager.setRequestedMode(const FDv2Offline());

        async.elapse(const Duration(seconds: 5));
        expect(calls, isEmpty);
      });
    });
  });

  group('zero window (immediate mode)', () {
    test('changes fire synchronously without a timer', () {
      final calls = <DebouncedState>[];
      final manager = StateDebounceManager(
        initialState: _initial,
        debounceWindow: Duration.zero,
        onReconcile: calls.add,
      );

      manager.setNetworkAvailable(false);
      expect(calls, hasLength(1));
      expect(calls.single.networkAvailable, isFalse);

      manager.setInForeground(false);
      expect(calls, hasLength(2));
      expect(calls.last.inForeground, isFalse);

      manager.close();
    });

    test('unchanged setters do not fire even in immediate mode', () {
      final calls = <DebouncedState>[];
      final manager = StateDebounceManager(
        initialState: _initial,
        debounceWindow: Duration.zero,
        onReconcile: calls.add,
      );

      manager.setNetworkAvailable(true);
      manager.setInForeground(true);
      manager.setRequestedMode(null);

      expect(calls, isEmpty);
      manager.close();
    });
  });
}
