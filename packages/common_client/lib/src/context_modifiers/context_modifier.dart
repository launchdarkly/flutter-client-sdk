import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

/// Context modifiers are intended to take an initial context and modifiers
/// it with additional, or modified, data.
///
/// This includes generating keys for anonymous contexts as well as adding
/// information for the auto-env attributes feature.
abstract interface class ContextModifier {
  Future<LDContext> decorate(LDContext context);
}
