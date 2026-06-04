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
  group('initial reconcile', () {
    test('is buffered on the stream and delivered to the first subscriber',
        () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
        );
        final sub = manager.stream.listen(calls.add);

        expect(calls, isEmpty,
            reason: 'must not deliver synchronously inside subscribe');
        async.flushMicrotasks();
        expect(calls, hasLength(1));
        expect(calls.single, same(_initial));

        sub.cancel();
        manager.close();
      });
    });

    test('arrives asynchronously even when debounceWindow is zero', () {
      // The deferred delivery is part of the contract: subscribers must
      // never see the initial reconcile arrive inside subscribe().
      final calls = <DebouncedState>[];
      final manager = StateDebounceManager(
        initialState: _initial,
        debounceWindow: Duration.zero,
      );
      final sub = manager.stream.listen(calls.add);
      expect(calls, isEmpty);

      sub.cancel();
      manager.close();
    });

    test(
        'is dropped if the subscription is cancelled before delivery drains',
        () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
        );
        final sub = manager.stream.listen(calls.add);

        sub.cancel();
        async.elapse(const Duration(seconds: 1));
        expect(calls, isEmpty);

        manager.close();
      });
    });
  });

  group('default window', () {
    test('does not fire when state never changes', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
        );
        final sub = manager.stream.listen(calls.add);
        async.flushMicrotasks();
        calls.clear();

        manager.setNetworkAvailable(true);
        manager.setInForeground(true);

        async.elapse(const Duration(seconds: 5));
        expect(calls, isEmpty);

        sub.cancel();
        manager.close();
      });
    });

    test('fires once after the window closes following a single change', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
        );
        final sub = manager.stream.listen(calls.add);
        async.flushMicrotasks();
        calls.clear();

        manager.setNetworkAvailable(false);
        async.elapse(_debounceWindow);

        expect(calls, hasLength(1));
        expect(calls.single.networkAvailable, isFalse);

        sub.cancel();
        manager.close();
      });
    });

    test('rapid changes reset the timer; one fire after final quiet', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
        );
        final sub = manager.stream.listen(calls.add);
        async.flushMicrotasks();
        calls.clear();

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

        sub.cancel();
        manager.close();
      });
    });

    test('flap-and-return fires the resolved (matching-actual) state', () {
      // Starting from {online,...}, network flaps offline and back to online;
      // the resolved state matches the starting actual state. The debouncer
      // still fires (its job is to deliver the resolved tuple); the consumer
      // is responsible for the no-op-if-no-change check.
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
        );
        final sub = manager.stream.listen(calls.add);
        async.flushMicrotasks();
        calls.clear();

        manager.setNetworkAvailable(false);
        manager.setNetworkAvailable(true);
        manager.setNetworkAvailable(false);
        manager.setNetworkAvailable(true);

        async.elapse(_debounceWindow);
        expect(calls, hasLength(1));
        expect(calls.single.networkAvailable, isTrue);

        sub.cancel();
        manager.close();
      });
    });

    test('combined lifecycle + network change fires a single reconcile', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
        );
        final sub = manager.stream.listen(calls.add);
        async.flushMicrotasks();
        calls.clear();

        manager.setNetworkAvailable(false);
        async.elapse(const Duration(milliseconds: 100));
        manager.setInForeground(false);

        async.elapse(_debounceWindow);
        expect(calls, hasLength(1));
        expect(calls.single.networkAvailable, isFalse);
        expect(calls.single.inForeground, isFalse);

        sub.cancel();
        manager.close();
      });
    });

    test('requested mode change debounces along with the other axes', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
        );
        final sub = manager.stream.listen(calls.add);
        async.flushMicrotasks();
        calls.clear();

        manager.setRequestedMode(const FDv2Polling());
        async.elapse(_debounceWindow);

        expect(calls, hasLength(1));
        expect(calls.single.requestedMode, const FDv2Polling());

        sub.cancel();
        manager.close();
      });
    });

    test('close cancels a pending timer', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
        );
        final sub = manager.stream.listen(calls.add);
        async.flushMicrotasks();
        calls.clear();

        manager.setNetworkAvailable(false);
        manager.close();

        async.elapse(const Duration(seconds: 5));
        expect(calls, isEmpty);

        sub.cancel();
      });
    });

    test('setters after close do not schedule a new fire', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: _debounceWindow,
        );
        final sub = manager.stream.listen(calls.add);
        async.flushMicrotasks();
        calls.clear();

        manager.close();
        manager.setNetworkAvailable(false);
        manager.setInForeground(false);
        manager.setRequestedMode(const FDv2Offline());

        async.elapse(const Duration(seconds: 5));
        expect(calls, isEmpty);

        sub.cancel();
      });
    });
  });

  group('zero window (immediate mode)', () {
    test('setter-driven changes deliver on the next microtask', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: Duration.zero,
        );
        final sub = manager.stream.listen(calls.add);
        async.flushMicrotasks();
        calls.clear();

        manager.setNetworkAvailable(false);
        expect(calls, isEmpty,
            reason: 'must not deliver synchronously inside setter');
        async.flushMicrotasks();
        expect(calls, hasLength(1));
        expect(calls.single.networkAvailable, isFalse);

        manager.setInForeground(false);
        async.flushMicrotasks();
        expect(calls, hasLength(2));
        expect(calls.last.inForeground, isFalse);

        sub.cancel();
        manager.close();
      });
    });

    test('unchanged setters do not fire even in immediate mode', () {
      fakeAsync((async) {
        final calls = <DebouncedState>[];
        final manager = StateDebounceManager(
          initialState: _initial,
          debounceWindow: Duration.zero,
        );
        final sub = manager.stream.listen(calls.add);
        async.flushMicrotasks();
        calls.clear();

        manager.setNetworkAvailable(true);
        manager.setInForeground(true);
        manager.setRequestedMode(null);

        async.flushMicrotasks();
        expect(calls, isEmpty);

        sub.cancel();
        manager.close();
      });
    });
  });
}
