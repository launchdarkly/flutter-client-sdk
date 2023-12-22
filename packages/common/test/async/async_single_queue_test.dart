import 'dart:async';

import 'package:launchdarkly_dart_common/src/async/async_single_queue.dart';
import 'package:test/test.dart';

void main() {
  test('it executes the initial task it is given', () async {
    final queue = AsyncSingleQueue<bool>();
    final res = await queue.execute(() async => true);

    expect(res, isA<TaskComplete>());
    expect((res as TaskComplete).result, isTrue);
  });

  test('it will queue a second task is there is an active task', () async {
    final queue = AsyncSingleQueue<bool>();

    // Task 1 completer is used to make task 1 wait.
    final task1Completer = Completer<bool>();

    final res1Future = queue.execute(() async => await task1Completer.future);
    final res2Future = queue.execute(() async {
      return false;
    });

    expect(queue.hasPending, isTrue);

    task1Completer.complete(true);
    final res1 = await res1Future;
    expect(res1, isA<TaskComplete>());
    expect((res1 as TaskComplete).result, isTrue);
    expect(queue.hasPending, isFalse);

    final res2 = await res2Future;
    expect(res2, isA<TaskComplete>());
    expect((res2 as TaskComplete).result, isFalse);
  });

  test('it will shed intermediate tasks', () async {
    final queue = AsyncSingleQueue<bool>();

    // Task 1 completer is used to make task 1 wait.
    final task1Completer = Completer<bool>();

    final res1Future = queue.execute(() async => await task1Completer.future);
    // Task 2 is the one that will be shed.
    final res2Future = queue.execute(() async {
      // This will not get run, because this task will be shed.
      throw Exception('BOOM!');
    });
    final res3Future = queue.execute(() async {
      return false;
    });

    task1Completer.complete(true);

    final res1 = await res1Future;
    expect(res1, isA<TaskComplete>());
    expect((res1 as TaskComplete).result, isTrue);

    final res2 = await res2Future;
    expect(res2, isA<TaskShed>());

    final res3 = await res3Future;
    expect(res3, isA<TaskComplete>());
    expect((res3 as TaskComplete).result, isFalse);
  });

  test('it can handle tasks that throw an exception', () async {
    final queue = AsyncSingleQueue<bool>();
    final res = await queue.execute(() async => throw ('BOOM!'));

    expect(res, isA<TaskError>());
    expect((res as TaskError).error as String, 'BOOM!');
  });

  test('exhaustive matching can be used with the task result', () async {
    final queue = AsyncSingleQueue<String>();

    final task2Completer = Completer<String>();

    final res1 = await queue.execute(() async => throw ('BOOM!'));
    final future2 = queue.execute(() async => await task2Completer.future);

    final future3 = queue.execute(() async => throw ('is shed'));
    task2Completer.complete('good');
    final res4 = await queue.execute(() async => 'also good');

    // This test is also compilation. This should need updated if task
    // types are added.
    void doSwitch(TaskResult<String> res, String expected) {
      var actual = '';
      switch (res) {
        case TaskComplete<String>():
          actual = 'complete';
        case TaskShed<String>():
          actual = 'shed';
        case TaskError<String>():
          actual = 'error';
      }
      expect(actual, expected);
    }

    doSwitch(res1, 'error');
    doSwitch(await future2, 'complete');

    doSwitch(await future3, 'shed');
    doSwitch(res4, 'complete');
  });
}
