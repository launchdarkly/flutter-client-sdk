import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../../item_descriptor.dart';
import 'payload.dart';

/// The object kind for client-side flag evaluation results.
const String flagEvalKind = 'flag-eval';

/// Translates a wire-level [Payload] into a typed [ChangeSet] ready for
/// the flag store.
///
/// Throws if any flag-eval object cannot be parsed. The data source layer
/// calls this at acquisition time and reports a failure as a data source
/// error, so the connection recovers rather than the failure surfacing
/// later at apply time.
ChangeSet translatePayload(Payload payload) {
  return ChangeSet(
    selector: payload.selector,
    type: payload.type,
    updates: mapUpdatesToItemDescriptors(payload.updates),
  );
}

/// Converts FDv2 [Update] objects to a map of [ItemDescriptor]s suitable
/// for the flag store.
///
/// Only processes updates with kind [flagEvalKind]; other kinds are
/// silently ignored.
Map<String, ItemDescriptor> mapUpdatesToItemDescriptors(List<Update> updates) {
  final result = <String, ItemDescriptor>{};
  for (final update in updates) {
    if (update.kind != flagEvalKind) {
      continue;
    }

    if (update.deleted) {
      result[update.key] = ItemDescriptor(version: update.version);
    } else if (update.object case final object?) {
      try {
        final evalResult = LDEvaluationResultSerialization.fromJson({
          ...object,
          // The envelope version is authoritative for FDv2 objects. The
          // flag-eval object itself carries only flagVersion -- there is
          // no in-object version on the wire -- so the envelope version
          // becomes the result's version, replacing any present.
          'version': update.version,
        });
        result[update.key] = ItemDescriptor(
          version: update.version,
          flag: evalResult,
        );
      } catch (_) {
        // Treat an unparseable flag_eval as a data source error. Rethrow
        // so the caller can discard the in-progress payload and
        // reconnect.
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
