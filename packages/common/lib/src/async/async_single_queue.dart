import 'dart:async';

sealed class TaskResult<TTaskReturn> {}

final class TaskComplete<TTaskReturn> implements TaskResult<TTaskReturn> {
  final TTaskReturn? result;

  TaskComplete(this.result);
}

final class TaskShed<TTaskReturn> implements TaskResult<TTaskReturn> {}

final class TaskError<TTaskReturn> implements TaskResult<TTaskReturn> {
  final Object error;

  TaskError(this.error);
}

/// Represents a pending task. This encapsulates the async function that needs
/// to be executed as well as a completer to indicate when that task
/// has been finished.
/// 
/// All tasks should have either [execute] or the [shed] method eventually
/// called.
///
/// A task that throws an exception will result in a [TaskError].
final class _Pending<TTaskReturn> {
  final Future<TTaskReturn> Function() _fn;
  final Completer<TaskResult<TTaskReturn>> _completer;

  _Pending(this._fn, this._completer);

  Future<TaskResult<TTaskReturn>> execute() {
    this
        ._fn()
        .then((value) => _completer.complete(TaskComplete(value)))
        .catchError((err) => _completer.complete(TaskError(err)));
    return this._completer.future;
  }

  void shed() {
    this._completer.complete(TaskShed());
  }
}

/// A queue, with a depth of 1, which allows for pending async actions
/// to be replaced.
///
/// This is useful when you have asynchronous operations where intermediate
/// operations can be discarded.
///
/// For instance, the SDK can only have one active context at a time, if
/// you request identification of many contexts, then the ultimate state
/// will be based on the last request. The intermediate identifies can be
/// discarded.
///
/// This class will always begin execution of the first item added to the queue,
/// at that point the item itself is not queued, but active. If another request
/// is made while that item is still active, then it is added to the queue.
/// A third request would then replace the second request if the second
/// request had not yet become active.
///
/// Once a task is active the queue will complete it. It doesn't cancel
/// tasks that it has started, but it can shed tasks that have not started.
///
/// [TTaskReturn] Is the return type of the task to be executed. Tasks accept no
/// parameters. So if you need parameters you should use a lambda to capture
/// them.
///
/// Implementation note: The functions themselves execute synchronously, even
/// those that return promises. This makes it easier to ensure that we don't
/// have the opportunity for these functions to have problem with
/// interleaved operations.
final class AsyncSingleQueue<TTaskReturn> {
  Future<TaskResult<TTaskReturn>>? _active;
  _Pending<TTaskReturn>? _pending;

  Future<TaskResult<TTaskReturn>> execute(Future<TTaskReturn> Function() task) {
    final completer = Completer<TaskResult<TTaskReturn>>();

    final asPending = _Pending(task, completer);

    // If there is no pending task, then we set this task as pending and
    // immediately execute it.
    if (_pending == null) {
      _pending = asPending;
      _checkPending();
      return completer.future;
    }

    // If there is a pending task, then we shed that task and set a new pending
    // task.
    _pending!.shed();
    _pending = asPending;

    return completer.future;
  }

  void _checkPending() {
    // If there is an active task, then we do not need to do anything.
    // When the active task is completed then a check for pending
    // will be done.
    if (_active != null) {
      return;
    }
    if (_pending != null) {
      var tmpPending = _pending;
      _pending = null;
      _active = tmpPending!.execute();
      _active!.then((value) {
        _active = null;
        _checkPending();
      });
    }
  }

  /// The primary purpose of this getter is for testing. It is not recommended
  /// to make logic that depends on checking for a pending task.
  bool get hasPending => _pending != null;
}
