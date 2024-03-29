import 'package:test/test.dart';
import 'package:launchdarkly_dart_common/src/collections.dart';

void main() {
  test('equivalent arrays are equal', () {
    final listA = ['a', 'b', 'c'];
    final listB = ['a', 'b', 'c'];
    expect(listA.equals(listB), true);
  });

  test('non-equivalent arrays are not equal', () {
    final listA = ['a', 'b', 'c'];
    final listB = ['a', 'c', 'c'];
    expect(listA.equals(listB), false);
  });

  test('equivalent maps are equal', () {
    final mapA = {'a': 1, 'b': 2, 'c': 3};
    final mapB = {'a': 1, 'b': 2, 'c': 3};
    expect(mapA.equals(mapB), true);
  });

  test('non-equivalent maps are not equal', () {
    final mapA = {'a': 1, 'b': 2, 'c': 3};
    final mapB = {'a': 1, 'b': 2, 'c': 3};
    expect(mapA.equals(mapB), true);
  });

  test('can async reduce', () async {
    final items = [1, 2, 3, 4];
    final res = await items.asyncReduce((current, accumulator) async {
      await Future.delayed(Duration(milliseconds: current));
      return accumulator + current;
    }, 5);

    expect(res, 15);
  });

  test('equal sets are equal', () {
    final setA = {'one', 'two', 'three'};
    final setB = {'two', 'one', 'three'};
    expect(setA, setB);
  });

  test('non-equal sets are not equal', () {
    final setA = {'one', 'two', 'three'};
    final setB = {'two', 'one', 'potato'};
    expect(setA, isNot(setB));
  });
}
