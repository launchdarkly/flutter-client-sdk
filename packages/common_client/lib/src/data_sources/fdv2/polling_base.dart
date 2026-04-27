import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'flag_eval_mapper.dart';
import 'payload.dart';
import 'protocol_handler.dart';
import 'protocol_types.dart';
import 'requestor.dart';
import 'selector.dart';
import 'source_result.dart';

/// Performs a single FDv2 poll and translates the response into an
/// [FDv2SourceResult].
///
/// Wraps an [FDv2Requestor] with FDv2 protocol semantics:
///
/// - Network errors --> [SourceState.interrupted].
/// - `x-ld-fd-fallback: true` header --> terminal error with
///   `fdv1Fallback: true`.
/// - HTTP `304 Not Modified` --> an empty change set with
///   [PayloadType.none], confirming the cached data is current.
/// - Other 4xx/5xx --> interrupted (recoverable) or terminalError
///   (non-recoverable) based on [isHttpGloballyRecoverable].
/// - `200` --> body is parsed as an [FDv2EventsCollection] and fed
///   through an [FDv2ProtocolHandler]. The first emitted action
///   determines the result.
final class FDv2PollingBase {
  final LDLogger _logger;
  final FDv2Requestor _requestor;
  final DateTime Function() _now;

  FDv2PollingBase({
    required LDLogger logger,
    required FDv2Requestor requestor,
    DateTime Function()? now,
  })  : _logger = logger.subLogger('FDv2PollingBase'),
        _requestor = requestor,
        _now = now ?? DateTime.now;

  /// Performs a single poll. Never throws; all errors are reported as
  /// [StatusResult]s.
  Future<FDv2SourceResult> pollOnce({Selector basis = Selector.empty}) async {
    final RequestorResponse response;
    try {
      response = await _requestor.request(basis: basis);
    } catch (err) {
      _logger.warn('Polling request failed: $err');
      return FDv2SourceResults.interrupted(message: err.toString());
    }
    return _processResponse(response);
  }

  FDv2SourceResult _processResponse(RequestorResponse response) {
    final fdv1Fallback = response.headers['x-ld-fd-fallback'] == 'true';
    final environmentId = response.headers['x-ld-envid'];

    if (fdv1Fallback) {
      return FDv2SourceResults.terminalError(
        statusCode: response.status,
        message: 'Server requested FDv1 fallback',
        fdv1Fallback: true,
      );
    }

    // 304 Not Modified means the SDK's cached data is confirmed current.
    if (response.status == 304) {
      return ChangeSetResult(
        payload: const Payload(type: PayloadType.none, updates: []),
        environmentId: environmentId,
        freshness: _now(),
        persist: true,
      );
    }

    if (response.status >= 400) {
      final message = 'Received unexpected status code: ${response.status}';
      if (isHttpGloballyRecoverable(response.status)) {
        return FDv2SourceResults.interrupted(
          statusCode: response.status,
          message: message,
        );
      }
      return FDv2SourceResults.terminalError(
        statusCode: response.status,
        message: message,
      );
    }

    return _parseBody(response, environmentId: environmentId);
  }

  FDv2SourceResult _parseBody(
    RequestorResponse response, {
    String? environmentId,
  }) {
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return FDv2SourceResults.interrupted(
          statusCode: response.status,
          message: 'Polling response was not a JSON object',
        );
      }
      json = decoded;
    } catch (err) {
      _logger.error('Failed to parse polling response body as JSON: $err');
      return FDv2SourceResults.interrupted(
        statusCode: response.status,
        message: 'Polling response body was not valid JSON',
      );
    }

    final collection = FDv2EventsCollection.fromJson(json);
    final handler = FDv2ProtocolHandler(
      objProcessors: {flagEvalKind: processFlagEval},
      logger: _logger,
    );

    for (final event in collection.events) {
      final action = handler.processEvent(event);
      switch (action) {
        case ActionPayload(:final payload):
          return ChangeSetResult(
            payload: payload,
            environmentId: environmentId,
            freshness: _now(),
            persist: true,
          );
        case ActionGoodbye(:final reason):
          return FDv2SourceResults.goodbyeResult(message: reason);
        case ActionServerError(:final reason):
          return FDv2SourceResults.interrupted(message: reason);
        case ActionError(:final message):
          return FDv2SourceResults.interrupted(message: message);
        case ActionNone():
          // Continue accumulating events until a payload-transferred or
          // terminal action is reached.
          break;
      }
    }

    // The response had no payload-transferred event. The protocol handler
    // is left in a partial state with nothing to emit, which is a
    // protocol violation for a polling response.
    return FDv2SourceResults.interrupted(
      statusCode: response.status,
      message: 'Polling response did not include a complete payload',
    );
  }
}
