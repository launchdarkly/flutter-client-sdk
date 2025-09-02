import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../persistence/persistence.dart';
import 'context_modifier.dart';
import 'utils.dart';

const _anonContextKeyNamespace = 'LaunchDarkly_AnonContextKey';

final class AnonymousContextModifier implements ContextModifier {
  final Persistence _persistence;
  final LDLogger _logger;

  AnonymousContextModifier(Persistence persistence, LDLogger logger)
      : _persistence = persistence,
        _logger = logger;

  /// For any anonymous contexts, which do not have keys specified, generate
  /// or read a persisted key for the anonymous kinds present. If persistence
  /// is available, then the key will be stable.
  @override
  Future<LDContext> decorate(LDContext context) async {
    if (!context.valid) {
      _logger.warn(
          'AnonymousContextModifier was asked to modify an invalid context and will attempt to do so. This is expected if starting with an empty context.');
    }
    // Before we make a builder we should check if any anonymous contexts
    // without keys exist.
    final containsContextToDecorate = _checkForAnonContexts(context);

    if (containsContextToDecorate) {
      final newBuilder = LDContextBuilder.fromContext(context);
      for (var MapEntry(key: kind, value: attributes)
          in context.attributesByKind.entries) {
        if (attributes.anonymous && attributes.key == '') {
          newBuilder.kind(
              kind,
              await getOrGenerateKey(
                  _persistence, _anonContextKeyNamespace, kind));
        }
      }
      return newBuilder.build();
    }
    return context;
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
