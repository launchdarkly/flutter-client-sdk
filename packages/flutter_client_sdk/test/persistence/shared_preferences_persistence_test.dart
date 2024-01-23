import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/src/persistence/shared_preferences_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('it can set a value', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = SharedPreferencesPersistence();
    // Just testing it doesn't throw basically.
    await persistence.set('LaunchDarkly_test', 'test-key', 'data');
  });

  test('it can read a value', () async {
    SharedPreferences.setMockInitialValues(
        {'LaunchDarkly_test.test-key': 'data'});
    final persistence = SharedPreferencesPersistence();
    final read = await persistence.read('LaunchDarkly_test', 'test-key');
    expect(read, 'data');
  });

  test('it can remove a value', () async {
    SharedPreferences.setMockInitialValues(
        {'LaunchDarkly_test.test-key': 'data'});
    final persistence = SharedPreferencesPersistence();
    await persistence.remove('LaunchDarkly_test', 'test-key');
    final read = await persistence.read('LaunchDarkly_test', 'test-key');
    expect(read, isNull);
  });
}
