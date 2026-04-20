import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:test/test.dart';

void main() {
  group('Selector', () {
    test('empty selector has null state and zero version', () {
      expect(Selector.empty.state, isNull);
      expect(Selector.empty.version, equals(0));
      expect(Selector.empty.isEmpty, isTrue);
      expect(Selector.empty.isNotEmpty, isFalse);
    });

    test('empty singleton is identical across references', () {
      expect(identical(Selector.empty, Selector.empty), isTrue);
    });

    test('constructed with state and version is not empty', () {
      final sel = Selector(state: '(p:abc:42)', version: 42);
      expect(sel.state, equals('(p:abc:42)'));
      expect(sel.version, equals(42));
      expect(sel.isEmpty, isFalse);
      expect(sel.isNotEmpty, isTrue);
    });

    test('equality requires matching emptiness, state, and version', () {
      final a = Selector(state: 'state-1', version: 1);
      final b = Selector(state: 'state-1', version: 1);
      final c = Selector(state: 'state-1', version: 2);
      final d = Selector(state: 'state-2', version: 1);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('non-empty selector is not equal to empty selector', () {
      final sel = Selector(state: 'something', version: 1);
      expect(sel, isNot(equals(Selector.empty)));
      expect(Selector.empty, isNot(equals(sel)));
    });

    test('toString differentiates empty and non-empty', () {
      expect(Selector.empty.toString(), equals('Selector(empty)'));

      final sel = Selector(state: 'my-state', version: 10);
      expect(sel.toString(), contains('my-state'));
      expect(sel.toString(), contains('10'));
    });
  });
}
