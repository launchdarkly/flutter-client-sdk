import 'dart:math';

import 'package:launchdarkly_common_client/src/data_sources/fdv2/fallback_directive.dart';
import 'package:test/test.dart';

final class FixedRandom implements Random {
  final int Function(int max) _nextInt;

  FixedRandom(this._nextInt);

  @override
  int nextInt(int max) => _nextInt(max);

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  group('resolveFallbackTtl', () {
    for (final ttl in [
      const Duration(seconds: 1),
      const Duration(seconds: 90),
      const Duration(hours: 1),
    ]) {
      test('uses a valid TTL of ${ttl.inSeconds}s as-is', () {
        expect(resolveFallbackTtl(ttl), ttl);
      });
    }

    for (final ttl in <Duration?>[
      null,
      Duration.zero,
      const Duration(seconds: -5),
      const Duration(seconds: 3601),
    ]) {
      test('replaces a TTL of ${ttl?.inSeconds}s with the jittered default',
          () {
        for (var i = 0; i < 100; i++) {
          final resolved = resolveFallbackTtl(ttl);
          expect(resolved, greaterThanOrEqualTo(const Duration(minutes: 30)));
          expect(resolved, lessThanOrEqualTo(const Duration(hours: 1)));
        }
      });
    }

    test('the jitter spans the full range from 30 minutes to 1 hour', () {
      expect(resolveFallbackTtl(null, FixedRandom((max) => 0)),
          const Duration(hours: 1));
      expect(resolveFallbackTtl(null, FixedRandom((max) => max - 1)),
          const Duration(minutes: 30));
    });
  });

  group('readFallbackDirective', () {
    test('returns null without the fallback header', () {
      expect(readFallbackDirective({'x-ld-fd-fallback-ttl': '60'}), isNull);
    });

    test('carries a malformed TTL header as null', () {
      final directive = readFallbackDirective(
          {'x-ld-fd-fallback': 'true', 'x-ld-fd-fallback-ttl': 'soon'});

      expect(directive, isNotNull);
      expect(directive!.ttl, isNull);
    });
  });
}
