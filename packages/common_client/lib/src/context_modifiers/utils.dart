import 'package:uuid/uuid.dart';
import '../persistence/persistence.dart';

/// The key lookups in progress, by persistence, namespace, and kind.
final _inProgress = <(Persistence, String, String), Future<String>>{};

/// Retrieves the key from [persistence] for the given [namespace] and [kind] if it exists.  If
/// one does not exist, generates a key, saves it, and returns it. Concurrent
/// calls with the same arguments return the same key.
Future<String> getOrGenerateKey(
    Persistence persistence, String namespace, String kind) {
  final id = (persistence, namespace, kind);
  return _inProgress[id] ??=
      _getOrGenerateKey(persistence, namespace, kind).whenComplete(() {
    _inProgress.remove(id);
  });
}

Future<String> _getOrGenerateKey(
    Persistence persistence, String namespace, String kind) async {
  final encodedKind = encodePersistenceKey(kind);
  final stored = await persistence.read(namespace, encodedKind);
  if (stored != null) {
    return stored;
  }
  final newKey = Uuid().v4();
  await persistence.set(namespace, encodedKind, newKey);
  return newKey;
}
