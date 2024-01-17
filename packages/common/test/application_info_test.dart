import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:test/test.dart';

void main() {
  test('equivalent application info objects are equal', () {
    final a = ApplicationInfo(
        applicationId: 'app-id',
        applicationName: 'app-name',
        applicationVersion: '1.0.0.0.0.1',
        applicationVersionName: '1');
    final b = ApplicationInfo(
        applicationId: 'app-id',
        applicationName: 'app-name',
        applicationVersion: '1.0.0.0.0.1',
        applicationVersionName: '1');

    expect(a, b);
  });

  test('non-equivalent application info objects are not equal', () {
    final a = ApplicationInfo(
        applicationId: 'app-id',
        applicationName: 'app-name',
        applicationVersion: '1.0.0.0.0.2',
        applicationVersionName: '1');
    final b = ApplicationInfo(
        applicationId: 'app-id',
        applicationName: 'app-name',
        applicationVersion: '1.0.0.0.0.1',
        applicationVersionName: '1');

    expect(a, isNot(b));
  });

  test('equivalent application info objects have equal hash codes', () {
    final a = ApplicationInfo(
        applicationId: 'app-id',
        applicationName: 'app-name',
        applicationVersion: '1.0.0.0.0.1',
        applicationVersionName: '1');
    final b = ApplicationInfo(
        applicationId: 'app-id',
        applicationName: 'app-name',
        applicationVersion: '1.0.0.0.0.1',
        applicationVersionName: '1');

    expect(a.hashCode, b.hashCode);
  });

  test('non-equivalent application info objects do not have equal hash codes',
      () {
    final a = ApplicationInfo(
        applicationId: 'app-id',
        applicationName: 'app-name',
        applicationVersion: '1.0.0.0.0.2',
        applicationVersionName: '1');
    final b = ApplicationInfo(
        applicationId: 'app-id',
        applicationName: 'app-name',
        applicationVersion: '1.0.0.0.0.1',
        applicationVersionName: '1');

    expect(a.hashCode, isNot(b.hashCode));
  });

  test('it produces the expected string', () {
    final a = ApplicationInfo(
        applicationId: 'app-id',
        applicationName: 'app-name',
        applicationVersion: '1.0.0.0.0.1',
        applicationVersionName: '1');
    expect(a.toString(),
        'ApplicationInfo{applicationId: app-id, applicationName: app-name, applicationVersion: 1.0.0.0.0.1, applicationVersionName: 1}');
  });

  test('it sanitizes items', () {
    final a = ApplicationInfo(
        applicationId: 'app id',
        applicationName: 'app name',
        applicationVersion: '1 0.0.0.0.1',
        applicationVersionName: '1 0');
    final b = ApplicationInfo(
        applicationId: 'app-id',
        applicationName: 'app-name',
        applicationVersion: '1-0.0.0.0.1',
        applicationVersionName: '1-0');

    expect(a, b);
  });

  test('empty fields are not included', () {
    final a = ApplicationInfo(
        applicationId: '',
        applicationName: '',
        applicationVersion: '',
        applicationVersionName: '');


    expect(a.applicationId, isNull);
    expect(a.applicationName, isNull);
    expect(a.applicationVersion, isNull);
    expect(a.applicationVersionName, isNull);
  });
}
