import 'dart:async';
import 'dart:collection';

/// A simple asynchronous producer/consumer queue.
///
/// Producers call [put] to add items. Consumers call [take] to retrieve
/// items. If no item is available, [take] returns a Future that completes
/// when an item is put.
final class AsyncQueue<T> {
  final Queue<T> _items = Queue();
  final Queue<Completer<T>> _waiters = Queue();
  bool _closed = false;

  /// Adds an item to the queue. If a consumer is waiting, the item is
  /// delivered immediately.
  void put(T item) {
    if (_closed) return;

    if (_waiters.isNotEmpty) {
      final waiter = _waiters.removeFirst();
      waiter.complete(item);
    } else {
      _items.add(item);
    }
  }

  /// Takes an item from the queue. If no item is available, returns a
  /// Future that completes when an item is added.
  ///
  /// Throws [StateError] if the queue has been closed and is empty.
  Future<T> take() {
    if (_items.isNotEmpty) {
      return Future.value(_items.removeFirst());
    }

    if (_closed) {
      return Future.error(StateError('Queue is closed'));
    }

    final completer = Completer<T>();
    _waiters.add(completer);
    return completer.future;
  }

  /// Closes the queue. Pending waiters will receive a [StateError].
  void close() {
    _closed = true;
    while (_waiters.isNotEmpty) {
      final waiter = _waiters.removeFirst();
      waiter.completeError(StateError('Queue is closed'));
    }
  }

  /// Whether the queue has been closed.
  bool get isClosed => _closed;

  /// Whether the queue has items available for immediate consumption.
  bool get isNotEmpty => _items.isNotEmpty;

  /// The number of items currently buffered.
  int get length => _items.length;
}
