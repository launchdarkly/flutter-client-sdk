import 'package:test/test.dart';

import 'package:launchdarkly_common_client/src/hooks/operations.dart';
import 'package:launchdarkly_common_client/src/hooks/hook.dart';

final class TestHook extends Hook {
  final String hookName;
  final HookMetadata _metadata;

  TestHook(this.hookName) : _metadata = HookMetadata(name: hookName);

  @override
  HookMetadata get metadata => _metadata;
}

void main() {
  group('combineHooks', () {
    test('returns null when both lists are null', () {
      final result = combineHooks(null, null);
      expect(result, isNull);
    });

    test('returns extendedHooks when baseHooks is null', () {
      final hook1 = TestHook('hook-1');
      final hook2 = TestHook('hook-2');
      final extendedHooks = [hook1, hook2];

      final result = combineHooks(null, extendedHooks);

      expect(result, same(extendedHooks));
      expect(result, containsAll([hook1, hook2]));
    });

    test('returns baseHooks when extendedHooks is null', () {
      final hook1 = TestHook('hook-1');
      final hook2 = TestHook('hook-2');
      final baseHooks = [hook1, hook2];

      final result = combineHooks(baseHooks, null);

      expect(result, same(baseHooks));
      expect(result, containsAll([hook1, hook2]));
    });

    test('returns empty list when both lists are empty', () {
      final result = combineHooks([], []);

      expect(result, isNotNull);
      expect(result!, isEmpty);
    });

    test('returns baseHooks when extendedHooks is empty', () {
      final hook1 = TestHook('hook-1');
      final hook2 = TestHook('hook-2');
      final baseHooks = [hook1, hook2];

      final result = combineHooks(baseHooks, []);

      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result, containsAll([hook1, hook2]));
    });

    test('returns extendedHooks when baseHooks is empty', () {
      final hook1 = TestHook('hook-1');
      final hook2 = TestHook('hook-2');
      final extendedHooks = [hook1, hook2];

      final result = combineHooks([], extendedHooks);

      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result, containsAll([hook1, hook2]));
    });

    test('combines single hook from each list', () {
      final baseHook = TestHook('base-hook');
      final extendedHook = TestHook('extended-hook');

      final result = combineHooks([baseHook], [extendedHook]);

      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result, containsAll([baseHook, extendedHook]));
    });

    test('combines multiple hooks from both lists', () {
      final baseHook1 = TestHook('base-hook-1');
      final baseHook2 = TestHook('base-hook-2');
      final extendedHook1 = TestHook('extended-hook-1');
      final extendedHook2 = TestHook('extended-hook-2');
      final extendedHook3 = TestHook('extended-hook-3');

      final baseHooks = [baseHook1, baseHook2];
      final extendedHooks = [extendedHook1, extendedHook2, extendedHook3];

      final result = combineHooks(baseHooks, extendedHooks);

      expect(result, isNotNull);
      expect(result!.length, equals(5));
      expect(
          result,
          containsAll([
            baseHook1,
            baseHook2,
            extendedHook1,
            extendedHook2,
            extendedHook3
          ]));
    });

    test('preserves order with baseHooks first, then extendedHooks', () {
      final baseHook1 = TestHook('base-hook-1');
      final baseHook2 = TestHook('base-hook-2');
      final extendedHook1 = TestHook('extended-hook-1');
      final extendedHook2 = TestHook('extended-hook-2');

      final baseHooks = [baseHook1, baseHook2];
      final extendedHooks = [extendedHook1, extendedHook2];

      final result = combineHooks(baseHooks, extendedHooks);

      expect(result, isNotNull);
      expect(result!.length, equals(4));
      expect(result[0], same(baseHook1));
      expect(result[1], same(baseHook2));
      expect(result[2], same(extendedHook1));
      expect(result[3], same(extendedHook2));
    });

    test('handles duplicate hooks from both lists', () {
      final sharedHook = TestHook('shared-hook');
      final baseHook = TestHook('base-hook');
      final extendedHook = TestHook('extended-hook');

      final baseHooks = [baseHook, sharedHook];
      final extendedHooks = [sharedHook, extendedHook];

      final result = combineHooks(baseHooks, extendedHooks);

      expect(result, isNotNull);
      expect(result!.length, equals(4));
      expect(result, containsAll([baseHook, sharedHook, extendedHook]));
      // Verify the shared hook appears twice (once from each list)
      expect(result.where((hook) => hook == sharedHook).length, equals(2));
    });

    test('creates new list and does not modify original lists', () {
      final baseHook = TestHook('base-hook');
      final extendedHook = TestHook('extended-hook');

      final baseHooks = [baseHook];
      final extendedHooks = [extendedHook];
      final originalBaseHooksLength = baseHooks.length;
      final originalExtendedHooksLength = extendedHooks.length;

      final result = combineHooks(baseHooks, extendedHooks);

      // Verify original lists are unchanged
      expect(baseHooks.length, equals(originalBaseHooksLength));
      expect(extendedHooks.length, equals(originalExtendedHooksLength));
      expect(baseHooks, contains(baseHook));
      expect(baseHooks, isNot(contains(extendedHook)));
      expect(extendedHooks, contains(extendedHook));
      expect(extendedHooks, isNot(contains(baseHook)));

      // Verify result is a new list
      expect(result, isNot(same(baseHooks)));
      expect(result, isNot(same(extendedHooks)));
      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result, containsAll([baseHook, extendedHook]));
    });

    test('handles large lists efficiently', () {
      final baseHooks =
          List.generate(100, (index) => TestHook('base-hook-$index'));
      final extendedHooks =
          List.generate(50, (index) => TestHook('extended-hook-$index'));

      final result = combineHooks(baseHooks, extendedHooks);

      expect(result, isNotNull);
      expect(result!.length, equals(150));

      // Verify all base hooks are present in correct order
      for (int i = 0; i < 100; i++) {
        expect(result[i], same(baseHooks[i]));
      }

      // Verify all extended hooks are present in correct order after base hooks
      for (int i = 0; i < 50; i++) {
        expect(result[100 + i], same(extendedHooks[i]));
      }
    });
  });
}
