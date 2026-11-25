import 'dart:async';

import 'package:launchdarkly_common_client/src/context_modifiers/utils.dart';
import 'package:launchdarkly_common_client/src/persistence/persistence.dart';
import 'package:test/test.dart';

import '../mock_persistence.dart';

void main() {
  test('concurrent calls for the same kind return and store one key', () async {
    final gate = Completer<void>();
    final persistence = GatedPersistence(gate.future);

    final first = getOrGenerateKey(persistence, 'namespace', 'user');
    final second = getOrGenerateKey(persistence, 'namespace', 'user');
    gate.complete();
    final keys = await Future.wait([first, second]);

    // Both calls return the key that persistence stores.
    expect(keys[1], keys[0]);
    expect(persistence.storage['namespace']?[encodePersistenceKey('user')],
        keys[0]);
  });
}
