import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:test/test.dart';

void main() {
  group('Selector', () {
    test('empty selector has empty state and zero version', () {
      expect(Selector.empty.state, equals(''));
      expect(Selector.empty.version, equals(0));
      expect(Selector.empty.isEmpty, isTrue);
      expect(Selector.empty.isNotEmpty, isFalse);
    });

    test('from null state returns empty', () {
      expect(Selector.from(null), equals(Selector.empty));
    });

    test('from empty string returns empty', () {
      expect(Selector.from(''), equals(Selector.empty));
    });

    test('from null state ignores version', () {
      expect(Selector.from(null, version: 42), equals(Selector.empty));
    });

    test('from valid state creates selector with default version', () {
      final sel = Selector.from('(p:abc:42)');
      expect(sel.state, equals('(p:abc:42)'));
      expect(sel.version, equals(0));
      expect(sel.isEmpty, isFalse);
      expect(sel.isNotEmpty, isTrue);
    });

    test('from valid state and version creates selector', () {
      final sel = Selector.from('(p:abc:42)', version: 42);
      expect(sel.state, equals('(p:abc:42)'));
      expect(sel.version, equals(42));
      expect(sel.isEmpty, isFalse);
      expect(sel.isNotEmpty, isTrue);
    });

    test('equality requires both state and version', () {
      final a = Selector.from('state-1', version: 1);
      final b = Selector.from('state-1', version: 1);
      final c = Selector.from('state-1', version: 2);
      final d = Selector.from('state-2', version: 1);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('toString includes state and version', () {
      final sel = Selector.from('my-state', version: 10);
      expect(sel.toString(), contains('my-state'));
      expect(sel.toString(), contains('10'));
    });
  });
}
