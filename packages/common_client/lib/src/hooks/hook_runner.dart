import 'dart:collection';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show LDValue, LDContext, LDEvaluationDetail, LDLogger;

import '../ld_common_client.dart' show IdentifyResult, VariationMethodNames;
import 'hook.dart';

enum HookMethodNames {
  beforeEvaluation('beforeEvaluation'),
  afterEvaluation('afterEvaluation'),
  beforeIdentify('beforeIdentify'),
  afterIdentify('afterIdentify'),
  afterTrack('afterTrack');

  final String _value;

  const HookMethodNames(this._value);

  @override
  String toString() {
    return _value;
  }
}

// Shared instance to use whenever an empty unmodifiable map is required.
UnmodifiableMapView<String, LDValue> _baseData = UnmodifiableMapView({});

/// Safely executes a hook stage method and handles any exceptions that occur.
T _tryExecuteStage<T>(
  LDLogger logger,
  HookMethodNames method,
  String hookName,
  T Function() stage,
  T defaultValue,
) {
  try {
    return stage();
  } catch (err) {
    logger.error(
        'An error was encountered in "$method" of the "$hookName" hook: $err');
    return defaultValue;
  }
}

/// Executes the beforeEvaluation stage for all hooks.
List<UnmodifiableMapView<String, LDValue>> _executeBeforeEvaluation(
  LDLogger logger,
  List<Hook> hooks,
  EvaluationSeriesContext hookContext,
) {
  final results = <UnmodifiableMapView<String, LDValue>>[];
  UnmodifiableMapView<String, LDValue> currentData = _baseData;

  for (final hook in hooks) {
    currentData = _tryExecuteStage(
      logger,
      HookMethodNames.beforeEvaluation,
      hook.metadata.name,
      () => hook.beforeEvaluation(hookContext, currentData),
      currentData,
    );
    results.add(currentData);
  }

  return results;
}

/// Executes the afterEvaluation stage for all hooks in reverse order.
void _executeAfterEvaluation(
  LDLogger logger,
  List<Hook> hooks,
  EvaluationSeriesContext hookContext,
  List<UnmodifiableMapView<String, LDValue>> hookData,
  LDEvaluationDetail<LDValue> detail,
) {
  for (int i = hooks.length - 1; i >= 0; i--) {
    final hook = hooks[i];
    final data = i < hookData.length ? hookData[i] : _baseData;

    _tryExecuteStage(
      logger,
      HookMethodNames.afterEvaluation,
      hook.metadata.name,
      () => hook.afterEvaluation(hookContext, data, detail),
      data,
    );
  }
}

/// Executes the beforeIdentify stage for all hooks.
List<UnmodifiableMapView<String, LDValue>> _executeBeforeIdentify(
  LDLogger logger,
  List<Hook> hooks,
  IdentifySeriesContext hookContext,
) {
  final results = <UnmodifiableMapView<String, LDValue>>[];
  UnmodifiableMapView<String, LDValue> currentData = _baseData;

  for (final hook in hooks) {
    currentData = _tryExecuteStage(
      logger,
      HookMethodNames.beforeIdentify,
      hook.metadata.name,
      () => hook.beforeIdentify(hookContext, currentData),
      currentData,
    );
    results.add(currentData);
  }

  return results;
}

/// Executes the afterIdentify stage for all hooks in reverse order.
void _executeAfterIdentify(
  LDLogger logger,
  List<Hook> hooks,
  IdentifySeriesContext hookContext,
  List<UnmodifiableMapView<String, LDValue>> hookData,
  IdentifyResult result,
) {
  for (int i = hooks.length - 1; i >= 0; i--) {
    final hook = hooks[i];
    final data = i < hookData.length ? hookData[i] : _baseData;

    _tryExecuteStage(
      logger,
      HookMethodNames.afterIdentify,
      hook.metadata.name,
      () => hook.afterIdentify(hookContext, data, result),
      data,
    );
  }
}

/// Executes the afterTrack stage for all hooks.
void _executeAfterTrack(
  LDLogger logger,
  List<Hook> hooks,
  TrackSeriesContext hookContext,
) {
  for (final hook in hooks) {
    _tryExecuteStage(
      logger,
      HookMethodNames.afterTrack,
      hook.metadata.name,
      () => hook.afterTrack(hookContext),
      null,
    );
  }
}

/// Manages and executes hooks during various SDK operations.
///
/// The HookRunner coordinates the execution of hooks during flag evaluation,
/// context identification, and event tracking operations. It ensures proper
/// error handling so that hook failures don't compromise SDK functionality.
class HookRunner {
  final List<Hook> _hooks = <Hook>[];
  final LDLogger _logger;

  /// Creates a new HookRunner instance.
  ///
  /// [logger] is used for logging hook execution errors.
  /// [initialHooks] is the initial list of hooks to register.
  HookRunner(this._logger, [List<Hook>? initialHooks]) {
    if (initialHooks != null) {
      _hooks.addAll(initialHooks);
    }
  }

  /// Executes hooks around a flag evaluation operation.
  ///
  /// This method runs the beforeEvaluation hooks, executes the evaluation
  /// method, then runs the afterEvaluation hooks.
  ///
  /// [flagKey] is the key of the flag being evaluated.
  /// [context] is the evaluation context (may be null).
  /// [defaultValue] is the default value for the evaluation.
  /// [method] is the evaluation method to execute.
  /// [methodName] is the name of the variation method being called.
  /// [environmentId] is the optional environment ID for the evaluation.
  ///
  /// Returns the result of the evaluation method.
  LDEvaluationDetail<LDValue> withEvaluation(
    String flagKey,
    LDContext? context,
    LDValue defaultValue,
    VariationMethodNames methodName,
    LDEvaluationDetail<LDValue> Function() method, {
    String? environmentId,
  }) {
    if (_hooks.isEmpty) {
      return method();
    }

    // The collection of hooks should be stable for an evaluation, so we make
    // a shallow copy.
    final hooks = List<Hook>.from(_hooks);
    final hookContext = EvaluationSeriesContext.internal(
      flagKey: flagKey,
      context: context,
      defaultValue: defaultValue,
      method: methodName.toString(),
      environmentId: environmentId,
    );

    final hookData = _executeBeforeEvaluation(_logger, hooks, hookContext);
    final result = method();
    _executeAfterEvaluation(_logger, hooks, hookContext, hookData, result);

    return result;
  }

  /// Executes hooks around an identify operation.
  ///
  /// This method runs the beforeIdentify hooks and returns a callback
  /// that should be invoked with the identify result to run the afterIdentify hooks.
  ///
  /// [context] is the context being identified.
  ///
  /// Returns a function that should be called with the identify result.
  void Function(IdentifyResult) identify(LDContext context) {
    final hooks = List<Hook>.from(_hooks);
    final hookContext = IdentifySeriesContext.internal(context: context);
    final hookData = _executeBeforeIdentify(_logger, hooks, hookContext);

    return (IdentifyResult result) {
      _executeAfterIdentify(_logger, hooks, hookContext, hookData, result);
    };
  }

  /// Adds a hook to the runner.
  ///
  /// [hook] is the hook to add.
  void addHook(Hook hook) {
    _hooks.add(hook);
  }

  /// Executes the afterTrack hooks for a tracking operation.
  ///
  /// [hookContext] contains information about the track operation.
  void afterTrack(TrackSeriesContext hookContext) {
    if (_hooks.isEmpty) {
      return;
    }

    final hooks = List<Hook>.from(_hooks);
    _executeAfterTrack(_logger, hooks, hookContext);
  }
}
