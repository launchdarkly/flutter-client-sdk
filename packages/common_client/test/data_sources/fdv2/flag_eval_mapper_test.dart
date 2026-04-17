import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/flag_eval_mapper.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:test/test.dart';

void main() {
  group('mapUpdatesToItemDescriptors', () {
    test('converts put update to item descriptor with flag', () {
      final updates = [
        Update(
          kind: flagEvalKind,
          key: 'my-flag',
          version: 5,
          object: {
            'value': true,
            'version': 5,
            'variation': 0,
            'trackEvents': false,
          },
        ),
      ];

      final result = mapUpdatesToItemDescriptors(updates);

      expect(result, hasLength(1));
      expect(result.containsKey('my-flag'), isTrue);
      expect(result['my-flag']!.version, equals(5));
      expect(result['my-flag']!.flag, isNotNull);
      expect(result['my-flag']!.flag!.detail.value, equals(LDValue.ofBool(true)));
    });

    test('converts delete update to tombstone', () {
      final updates = [
        Update(
          kind: flagEvalKind,
          key: 'deleted-flag',
          version: 3,
          deleted: true,
        ),
      ];

      final result = mapUpdatesToItemDescriptors(updates);

      expect(result, hasLength(1));
      expect(result['deleted-flag']!.version, equals(3));
      expect(result['deleted-flag']!.flag, isNull);
    });

    test('ignores non-flag-eval kinds', () {
      final updates = [
        Update(
          kind: 'segment',
          key: 'my-segment',
          version: 1,
          object: {'key': 'seg-1'},
        ),
        Update(
          kind: flagEvalKind,
          key: 'my-flag',
          version: 2,
          object: {
            'value': 'hello',
            'version': 2,
            'variation': 1,
            'trackEvents': false,
          },
        ),
      ];

      final result = mapUpdatesToItemDescriptors(updates);

      expect(result, hasLength(1));
      expect(result.containsKey('my-flag'), isTrue);
      expect(result.containsKey('my-segment'), isFalse);
    });

    test('handles multiple updates', () {
      final updates = [
        Update(
          kind: flagEvalKind,
          key: 'flag-a',
          version: 1,
          object: {'value': true, 'version': 1},
        ),
        Update(
          kind: flagEvalKind,
          key: 'flag-b',
          version: 2,
          object: {'value': 'test', 'version': 2, 'variation': 0},
        ),
        Update(
          kind: flagEvalKind,
          key: 'flag-c',
          version: 3,
          deleted: true,
        ),
      ];

      final result = mapUpdatesToItemDescriptors(updates);

      expect(result, hasLength(3));
      expect(result['flag-a']!.flag, isNotNull);
      expect(result['flag-b']!.flag, isNotNull);
      expect(result['flag-c']!.flag, isNull);
    });

    test('returns empty map for empty updates', () {
      final result = mapUpdatesToItemDescriptors([]);
      expect(result, isEmpty);
    });

    test('handles flag with evaluation reason', () {
      final updates = [
        Update(
          kind: flagEvalKind,
          key: 'flag-with-reason',
          version: 7,
          object: {
            'value': 42,
            'version': 7,
            'variation': 2,
            'trackEvents': true,
            'trackReason': true,
            'reason': {'kind': 'FALLTHROUGH'},
          },
        ),
      ];

      final result = mapUpdatesToItemDescriptors(updates);

      expect(result, hasLength(1));
      final flag = result['flag-with-reason']!.flag!;
      expect(flag.trackEvents, isTrue);
      expect(flag.trackReason, isTrue);
      expect(flag.detail.reason, isNotNull);
    });

    test('handles flag with prerequisites', () {
      final updates = [
        Update(
          kind: flagEvalKind,
          key: 'flag-with-prereqs',
          version: 4,
          object: {
            'value': true,
            'version': 4,
            'variation': 0,
            'prerequisites': ['prereq-1', 'prereq-2'],
          },
        ),
      ];

      final result = mapUpdatesToItemDescriptors(updates);

      final flag = result['flag-with-prereqs']!.flag!;
      expect(flag.prerequisites, equals(['prereq-1', 'prereq-2']));
    });
  });

  group('processFlagEval', () {
    test('is a passthrough', () {
      final input = {'value': true, 'version': 1};
      final result = processFlagEval(input);
      expect(result, same(input));
    });
  });
}
