import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Interface for a data store that holds feature flag data and other SDK
/// properties in a serialized form.
///
/// This interface should be used for platform-specific integrations that store
/// data somewhere other than in memory.
///
/// Each data item is uniquely identified by the combination of a "namespace"
/// and a "key", and has a string value. These are defined as follows:
///
/// - Both the namespace and the key are non-empty string.
/// - Both the namespace and the key contain only alphanumeric characters,
///  hyphens, and underscores.
/// - The namespace always starts with "LaunchDarkly".
/// - The value can be any string, including an empty string.
///
/// The SDK assumes that the persistence is only being used by a single instance
/// of the SDK per SDK key (two different SDK instances, with 2 different SDK
/// keys could use the same persistence instance). It does not implement
/// read-through behavior. It reads values at SDK initialization or when
/// changing contexts.
///
/// The SDK, with correct usage, will not have overlapping writes to the same
/// key.
///
/// This interface does not depend on the ability to list the contents of the
/// store or namespaces. This is to maintain the simplicity of implementing a
/// key-value store on many platforms.
///
abstract interface class Persistence {
  /// Add or update a value in the store. If the value cannot be set, then
  /// the function should complete normally.
  Future<void> set(String namespace, String key, String data);

  /// Remove a value from the store. If the value cannot be removed, then
  /// the function should complete normally.
  Future<void> remove(String namespace, String key);

  /// Attempt to read a value from the store. If the value does not exist,
  /// or could not be read, then return null.
  Future<String?> read(String namespace, String key);
}

/// When a key needs to be encoded/decoded, because it contains
/// potentially unacceptable characters, then this method can be used.
String encodePersistenceKey(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  // This will be the hex encoded digest.
  return digest.toString();
}
