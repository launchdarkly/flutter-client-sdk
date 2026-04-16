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

    test('constructed with state and version', () {
      final sel = Selector(state: '(p:abc:42)', version: 42);
      expect(sel.state, equals('(p:abc:42)'));
      expect(sel.version, equals(42));
      expect(sel.isEmpty, isFalse);
      expect(sel.isNotEmpty, isTrue);
    });

    test('equality requires both state and version', () {
      final a = Selector(state: 'state-1', version: 1);
      final b = Selector(state: 'state-1', version: 1);
      final c = Selector(state: 'state-1', version: 2);
      final d = Selector(state: 'state-2', version: 1);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('empty string state is empty', () {
      final sel = Selector(state: '', version: 5);
      expect(sel.isEmpty, isTrue);
    });

    test('toString includes state and version', () {
      final sel = Selector(state: 'my-state', version: 10);
      expect(sel.toString(), contains('my-state'));
      expect(sel.toString(), contains('10'));
    });
  });
}
