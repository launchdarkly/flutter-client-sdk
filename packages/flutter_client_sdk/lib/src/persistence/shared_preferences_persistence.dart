import 'package:launchdarkly_common_client/ld_common_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An implementation of persistence which uses the shared_preferences plugin.
final class SharedPreferencesPersistence implements Persistence {
  final Future<SharedPreferences> _preferencesFuture =
      SharedPreferences.getInstance();

  Future<SharedPreferences> getPreferences() async {
    return _preferencesFuture;
  }

  String _makeKey(String namespace, String key) {
    return '$namespace.$key';
  }

  @override
  Future<String?> read(String namespace, String key) async {
    final preferences = await getPreferences();
    return preferences.getString(_makeKey(namespace, key));
  }

  @override
  Future<void> remove(String namespace, String key) async {
    final preferences = await getPreferences();
    preferences.remove(_makeKey(namespace, key));
  }

  @override
  Future<void> set(String namespace, String key, String data) async {
    final preferences = await getPreferences();
    preferences.setString(_makeKey(namespace, key), data);
  }
}
