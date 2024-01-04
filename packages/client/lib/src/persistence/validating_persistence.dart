import 'package:launchdarkly_dart_common/ld_common.dart';

import 'persistence.dart';

RegExp _validNamespaceOrKey = RegExp(r'^(\w|-)+$', unicode: false);

/// Verify that a given namespace and key are valid for use with persistence.
bool _validatePersistenceKey(String namespace, String key) {
  return namespace.startsWith('LaunchDarkly') &&
      _validNamespaceOrKey.hasMatch(namespace) &&
      _validNamespaceOrKey.hasMatch(key);
}

/// A persistence implementation which wraps another and extends it with
/// validation.
final class ValidatingPersistence implements Persistence {
  final Persistence _persistence;
  final LDLogger _logger;

  ValidatingPersistence(
      {required Persistence persistence, required LDLogger logger})
      : _logger = logger,
        _persistence = persistence;

  bool _isValid(String namespace, String key) {
    if (!_validatePersistenceKey(namespace, key)) {
      /// If this error happens it is indicative of an bug in the SDK code.
      /// It would represent an invalid constant or incorrect handling of
      /// an externally provided key.
      _logger.error(
          'Persistence namespace ($namespace) or key ($key) is not valid.');
      return false;
    }
    return true;
  }

  @override
  Future<String?> read(String namespace, String key) async {
    if (_isValid(namespace, key)) {
      return _persistence.read(namespace, key);
    }
    return null;
  }

  @override
  Future<void> remove(String namespace, String key) async {
    if (_isValid(namespace, key)) {
      _persistence.remove(namespace, key);
    }
  }

  @override
  Future<void> set(String namespace, String key, String data) async {
    if (_isValid(namespace, key)) {
      return _persistence.set(namespace, key, data);
    }
  }
}
