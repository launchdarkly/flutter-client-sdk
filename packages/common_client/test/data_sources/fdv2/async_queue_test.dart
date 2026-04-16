import 'package:launchdarkly_common_client/src/data_sources/fdv2/async_queue.dart';
import 'package:test/test.dart';

void main() {
  group('AsyncQueue', () {
    test('put then take returns item immediately', () async {
      final queue = AsyncQueue<int>();
      queue.put(1);
      queue.put(2);

      expect(await queue.take(), equals(1));
      expect(await queue.take(), equals(2));
    });

    test('take then put delivers item to waiter', () async {
      final queue = AsyncQueue<String>();

      final future = queue.take();
      queue.put('hello');

      expect(await future, equals('hello'));
    });

    test('multiple waiters served in order', () async {
      final queue = AsyncQueue<int>();

      final f1 = queue.take();
      final f2 = queue.take();
      final f3 = queue.take();

      queue.put(10);
      queue.put(20);
      queue.put(30);

      expect(await f1, equals(10));
      expect(await f2, equals(20));
      expect(await f3, equals(30));
    });

    test('close completes pending waiters with error', () async {
      final queue = AsyncQueue<int>();

      final future = queue.take();
      queue.close();

      expect(() => future, throwsA(isA<StateError>()));
    });

    test('take on closed empty queue throws', () async {
      final queue = AsyncQueue<int>();
      queue.close();

      expect(() => queue.take(), throwsA(isA<StateError>()));
    });

    test('put on closed queue is ignored', () {
      final queue = AsyncQueue<int>();
      queue.close();
      queue.put(1); // Should not throw
      expect(queue.length, equals(0));
    });

    test('isClosed reflects state', () {
      final queue = AsyncQueue<int>();
      expect(queue.isClosed, isFalse);
      queue.close();
      expect(queue.isClosed, isTrue);
    });

    test('isNotEmpty and length reflect buffered items', () {
      final queue = AsyncQueue<int>();
      expect(queue.isNotEmpty, isFalse);
      expect(queue.length, equals(0));

      queue.put(1);
      queue.put(2);
      expect(queue.isNotEmpty, isTrue);
      expect(queue.length, equals(2));
    });

    test('items remaining after close can still be consumed', () async {
      final queue = AsyncQueue<int>();
      queue.put(1);
      queue.put(2);
      queue.close();

      // Items already in the queue should still be retrievable
      expect(await queue.take(), equals(1));
      expect(await queue.take(), equals(2));
      // But the next take should fail
      expect(() => queue.take(), throwsA(isA<StateError>()));
    });

    test('interleaved puts and takes work correctly', () async {
      final queue = AsyncQueue<String>();

      queue.put('a');
      expect(await queue.take(), equals('a'));

      final future = queue.take();
      queue.put('b');
      expect(await future, equals('b'));

      queue.put('c');
      queue.put('d');
      expect(await queue.take(), equals('c'));
      expect(await queue.take(), equals('d'));
    });
  });
}
