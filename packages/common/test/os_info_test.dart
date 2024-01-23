import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

void main() {
  test('equivalent os info objects are equal', () {
    final a = OsInfo(family: 'Adams', name: 'Name', version: '42');
    final b = OsInfo(family: 'Adams', name: 'Name', version: '42');

    expect(a, b);

    final c = OsInfo(family: 'Adams');
    final d = OsInfo(family: 'Adams');

    expect(c, d);
  });

  test('non-equivalent os info objects are not equal', () {
    final a = OsInfo(family: 'Adams', name: 'Name', version: '42');
    final b = OsInfo(family: 'Adams', name: 'Name', version: '43');

    expect(a, isNot(b));
  });

  test('equivalent os info objects have equal hash codes', () {
    final a = OsInfo(family: 'Adams', name: 'Name', version: '42');
    final b = OsInfo(family: 'Adams', name: 'Name', version: '42');

    expect(a.hashCode, b.hashCode);
  });

  test('non-equivalent os info objects do not have equal hash codes', () {
    final a = OsInfo(family: 'Adams', name: 'Name', version: '42');
    final b = OsInfo(family: 'Adam', name: 'Name', version: '42');

    expect(a.hashCode, isNot(b.hashCode));
  });

  test('it produces the expected string', () {
    final a = OsInfo(family: 'Adams', name: 'Name', version: '42');
    expect(a.toString(), 'OsInfo{family: Adams, name: Name, version: 42}');

    final b = OsInfo(family: 'Adams');
    expect(b.toString(), 'OsInfo{family: Adams, name: null, version: null}');
  });
}
