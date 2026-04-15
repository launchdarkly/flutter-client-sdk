import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../../item_descriptor.dart';
import 'fdv2_payload.dart';

/// The object kind for client-side flag evaluation results.
const String flagEvalKind = 'flag-eval';

/// Converts FDv2 [Update] objects to a map of [ItemDescriptor]s suitable
/// for the flag store.
///
/// Only processes updates with kind [flagEvalKind]; other kinds are
/// silently ignored.
Map<String, ItemDescriptor> mapUpdatesToItemDescriptors(
    List<Update> updates) {
  final result = <String, ItemDescriptor>{};
  for (final update in updates) {
    if (update.kind != flagEvalKind) {
      continue;
    }

    if (update.deleted) {
      result[update.key] = ItemDescriptor(version: update.version);
    } else if (update.object != null) {
      try {
        final evalResult = LDEvaluationResultSerialization.fromJson(
            update.object!);
        result[update.key] = ItemDescriptor(
          version: update.version,
          flag: evalResult,
        );
      } catch (_) {
        // Per spec 4.1.2.1: treat unparseable flag_eval as a data source
        // error. Rethrow so the caller can discard the in-progress payload
        // and reconnect.
        rethrow;
      }
    }
  }
  return result;
}

/// An [ObjProcessor] for flag-eval kind objects. This is a passthrough
/// since client-side flag evaluations are pre-evaluated by the server.
Map<String, dynamic>? processFlagEval(Map<String, dynamic> object) {
  return object;
}
