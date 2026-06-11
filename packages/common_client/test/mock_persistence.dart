import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

final class MockPersistence implements Persistence {
  final storage = <String, Map<String, String>>{};

  /// Number of times [set] has been called.
  int setCallCount = 0;

  @override
  Future<String?> read(String namespace, String key) async {
    return storage[namespace]?[key];
  }

  @override
  Future<void> remove(String namespace, String key) async {
    storage[namespace]?.remove(key);
  }

  @override
  Future<void> set(String namespace, String key, String data) async {
    setCallCount += 1;
    if (!storage.containsKey(namespace)) {
      storage[namespace] = <String, String>{};
    }
    storage[namespace]![key] = data;
  }
}
