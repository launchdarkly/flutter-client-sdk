import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:test/test.dart';

void main() {
  group('Selector', () {
    test('empty selector has empty state', () {
      expect(Selector.empty.state, equals(''));
      expect(Selector.empty.isEmpty, isTrue);
      expect(Selector.empty.isNotEmpty, isFalse);
    });

    test('from null returns empty', () {
      expect(Selector.from(null), equals(Selector.empty));
    });

    test('from empty string returns empty', () {
      expect(Selector.from(''), equals(Selector.empty));
    });

    test('from valid state creates selector', () {
      final sel = Selector.from('(p:abc:42)');
      expect(sel.state, equals('(p:abc:42)'));
      expect(sel.isEmpty, isFalse);
      expect(sel.isNotEmpty, isTrue);
    });

    test('equality by state value', () {
      final a = Selector.from('state-1');
      final b = Selector.from('state-1');
      final c = Selector.from('state-2');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes state', () {
      final sel = Selector.from('my-state');
      expect(sel.toString(), contains('my-state'));
    });
  });
}
