import 'package:uuid/uuid.dart';
import '../persistence/persistence.dart';

/// Retrieves the key for the given [kind] from [persistence] if it exists.  If
/// one does not exist, generates a key, saves it, and returns it.
Future<String> getOrGenerateKey(Persistence persistence, String namespace, String kind) async {
  final encodedKind = encodePersistenceKey(kind);
  final stored = await persistence.read(namespace, encodedKind);
  if (stored != null) {
    return stored;
  }
  final newKey = Uuid().v4();
  await persistence.set(namespace, encodedKind, newKey);
  return newKey;
}
