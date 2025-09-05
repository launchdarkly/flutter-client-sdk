import 'dart:collection';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show LDValue, LDContext, LDEvaluationDetail;

import '../ld_common_client.dart' show IdentifyResult;

/// Meta-data about a hook implementation.
final class HookMetadata {
  /// The name of the hook.
  final String name;

  /// Construct a new hook metadata instance.
  /// Implementation note: If more fields are added then they must not be
  /// required constructor parameters for compatibility purposes.
  const HookMetadata({required this.name});

  @override
  String toString() {
    return 'HookMetadata{name: $name}';
  }
}

/// Contextual information provided to the evaluation stages.
final class EvaluationSeriesContext {
  /// The flag key the evaluation is for.
  final String flagKey;

  /// The context for the evaluation. Optional in case an evaluation is
  /// performed before the SDK has been started, or an invalid context is
  /// used.
  final LDContext? context;

  /// The default value that was provided for the evaluation.
  final LDValue defaultValue;

  /// The name of the method that was invoked to perform the evaluation.
  final String method;

  /// The environment ID associated with the evaluation if available.
  final String? environmentId;

  EvaluationSeriesContext.internal(
      {required this.flagKey,
      required this.context,
      required this.defaultValue,
      required this.method,
      required this.environmentId});

  @override
  String toString() {
    return 'EvaluationSeriesContext{flagKey: $flagKey, context: $context,'
        ' defaultValue: $defaultValue, method: $method,'
        ' environmentId: $environmentId}';
  }
}

/// Contextual information provided to identify stages.
final class IdentifySeriesContext {
  /// The context associated with the identify operation.
  final LDContext context;

  // Implementation note: Timeout not managed by SDK, so not included.
  // If the timeout does become managed by the SDK, then it should be
  // added here.

  IdentifySeriesContext.internal({required this.context});

  @override
  String toString() {
    return 'IdentifySeriesContext{context: $context}';
  }
}

/// Contextual information provided to track stages.
final class TrackSeriesContext {
  /// The key for the event being tracked.
  final String key;

  /// The context associated with the track operation.
  final LDContext context;

  /// The data associated with the track operation.
  final LDValue? data;

  /// The metric value associated with the track operation.
  final num? numericValue;

  TrackSeriesContext.internal(
      {required this.key, required this.context, this.data, this.numericValue});

  @override
  String toString() {
    return 'TrackSeriesContext{key: $key, context: $context,'
        ' data: $data, numericValue: $numericValue}';
  }
}

/// Base class for extending SDK functionality via hooks.
/// All hook implementations must derive from this class.
///
/// Default implementations are provided for each stage and an implementer
/// should override at least one of the stage methods.
///
/// All implementations must implement the metadata getter.
abstract base class Hook {
  /// Metadata associated with this hook.
  ///
  /// Hook implementations must implement this property.
  /// ```dart
  /// final _metadata = HookMetadata(name: 'MyHookName');
  ///
  /// @override
  /// HookMetadata get metadata => _metadata;
  /// ```
  HookMetadata get metadata;

  /// Construct a new hook instance.
  Hook();

  /// This method is called during the execution of a variation method before
  /// the flag value has been determined. The method is executed synchronously.
  ///
  /// [hookContext] Contains information about the evaluation being performed.
  /// [data] A record associated with each stage of hook invocations. Each stage
  /// is called with the data of the previous stage for a series. The input
  /// record should not be modified.
  ///
  /// Returns data to use when executing the next state of the hook in the
  /// evaluation series. It is recommended to expand the previous input into the
  /// return. This helps ensure your stage remains compatible moving forward as
  /// more stages are added.
  ///
  /// ```dart
  /// Map<String, LDValue> newData = Map.from(data);
  /// newData['new-key'] = LDValue.ofString('new-value');
  /// return UnmodifiableMapView(newData);
  /// ```
  UnmodifiableMapView<String, LDValue> beforeEvaluation(
      EvaluationSeriesContext hookContext,
      UnmodifiableMapView<String, LDValue> data) {
    return data;
  }

  /// This method is called during the execution of the variation method
  /// after the flag value has been determined. The method is executed
  /// synchronously.
  ///
  /// [hookContext] Contains information about the evaluation being performed.
  /// [data] A record associated with each stage of hook invocations. Each stage
  /// is called with the data of the previous stage for a series. The input
  /// record should not be modified.
  ///  [detail] The result of the evaluation.
  ///
  /// Returns data to use when executing the next state of the hook in the
  /// evaluation series. It is recommended to expand the previous input into the
  /// return. This helps ensure your stage remains compatible moving forward as
  /// more stages are added.
  ///
  /// ```dart
  /// Map<String, LDValue> newData = Map.from(data);
  /// newData['new-key'] = LDValue.ofString('new-value');
  /// return UnmodifiableMapView(newData);
  /// ```
  UnmodifiableMapView<String, LDValue> afterEvaluation(
      EvaluationSeriesContext hookContext,
      UnmodifiableMapView<String, LDValue> data,
      LDEvaluationDetail<LDValue> detail) {
    return data;
  }

  /// This method is called during the execution of the identify process before
  /// the operation completes, but after any context modifications are
  /// performed.
  ///
  /// [hookContext] Contains information about the evaluation being performed.
  /// [data] A record associated with each stage of hook invocations. Each stage
  /// is called with the data of the previous stage for a series. The input
  /// record should not be modified.
  ///
  /// Returns data to use when executing the next state of the hook in the
  /// evaluation series. It is recommended to expand the previous input into the
  /// return. This helps ensure your stage remains compatible moving forward as
  /// more stages are added.
  ///
  /// ```dart
  /// Map<String, LDValue> newData = Map.from(data);
  /// newData['new-key'] = LDValue.ofString('new-value');
  /// return UnmodifiableMapView(newData);
  /// ```
  UnmodifiableMapView<String, LDValue> beforeIdentify(
      IdentifySeriesContext hookContext,
      UnmodifiableMapView<String, LDValue> data) {
    return data;
  }

  /// This method is called during the execution of the identify process, after
  /// the operation completes.
  ///
  /// [hookContext] Contains information about the evaluation being performed.
  /// [data] A record associated with each stage of hook invocations. Each stage
  /// is called with the data of the previous stage for a series. The input
  /// record should not be modified.
  /// [result] The result of the identify operation.
  ///
  /// Returns data to use when executing the next state of the hook in the
  /// evaluation series. It is recommended to expand the previous input into the
  /// return. This helps ensure your stage remains compatible moving forward as
  /// more stages are added.
  ///
  /// ```dart
  /// Map<String, LDValue> newData = Map.from(data);
  /// newData['new-key'] = LDValue.ofString('new-value');
  /// return UnmodifiableMapView(newData);
  /// ```
  UnmodifiableMapView<String, LDValue> afterIdentify(
      IdentifySeriesContext hookContext,
      UnmodifiableMapView<String, LDValue> data,
      IdentifyResult result) {
    return data;
  }

  /// This method is called during the execution of the track process after the
  /// event has been enqueued.
  ///
  /// [hookContext] Contains information about the track operation being
  /// performed. This is not mutable.
  void afterTrack(TrackSeriesContext hookContext) {}
}
