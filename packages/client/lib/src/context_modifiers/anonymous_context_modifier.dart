import 'package:launchdarkly_dart_common/ld_common.dart';

import 'package:uuid/uuid.dart';

import '../persistence.dart';
import 'context_modifier.dart';

const _generatedKeyNamespace = 'LaunchDarkly_GeneratedContextKeys';

final class AnonymousContextModifier implements ContextModifier {
  final Persistence? _persistence;
  final Uuid _uuidSource = Uuid();
  final Map<String, String> _keyCache = {};

  AnonymousContextModifier(Persistence? persistence)
      : _persistence = persistence;

  /// For any anonymous contexts, which do not have keys specified, generate
  /// or read a persisted key for the anonymous kinds present. If persistence
  /// is available, then the key will be stable.
  @override
  Future<LDContext> decorate(LDContext context) async {
    if (!context.valid) {
      return context;
    }
    // Before we make a builder we should check if any anonymous contexts
    // without keys exist.
    final containsContextToDecorate = _checkForAnonContexts(context);

    if (containsContextToDecorate) {
      final newBuilder = LDContextBuilder.fromContext(context);
      for (var MapEntry(key: kind, value: attributes)
          in context.attributesByKind.entries) {
        if (attributes.anonymous && attributes.key == '') {
          newBuilder.kind(kind, await _getOrGenerateKey(kind));
        }
      }
      return newBuilder.build();
    }
    return context;
  }

  Future<String> _getOrGenerateKey(String kind) async {
    if (_keyCache.containsKey(kind)) {
      return _keyCache[kind]!;
    }
    final stored = await _persistence?.read(_generatedKeyNamespace, kind);
    if (stored != null) {
      return stored;
    }
    final newKey = _uuidSource.v4();
    _keyCache[kind] = newKey;
    await _persistence?.set(_generatedKeyNamespace, kind, newKey);
    return newKey;
  }

  bool _checkForAnonContexts(LDContext context) {
    var containsContextToDecorate = false;
    for (var MapEntry(key: _, value: attributes)
        in context.attributesByKind.entries) {
      if (attributes.anonymous && attributes.key == '') {
        containsContextToDecorate = true;
        break;
      }
    }
    return containsContextToDecorate;
  }
}
