import 'hook.dart';

List<Hook>? combineHooks(List<Hook>? baseHooks, List<Hook>? extendedHooks) {
  if (baseHooks == null) {
    return extendedHooks;
  }
  if (extendedHooks == null) {
    return baseHooks;
  }
  List<Hook> combined = [];
  combined.addAll(baseHooks);
  combined.addAll(extendedHooks);
  return combined;
}
