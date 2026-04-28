import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
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
/// - Network errors --> [SourceState.interrupted] with a sanitized
///   message.
/// - HTTP `304 Not Modified` --> an empty change set with
///   [PayloadType.none], confirming the cached data is current.
/// - Other 4xx/5xx --> interrupted (recoverable) or terminalError
///   (non-recoverable) based on [isHttpGloballyRecoverable].
/// - `200` --> body is parsed as an [FDv2EventsCollection] and fed
///   through an [FDv2ProtocolHandler]. The first emitted action
///   determines the result.
///
/// `x-ld-fd-fallback: true` is treated as an annotation on whatever
/// result the response would otherwise produce: the body is still
/// parsed and used, the 304 is still treated as no-op, errors are
/// still classified by status code, and `fdv1Fallback: true` is
/// stamped on the resulting [FDv2SourceResult]. The orchestrator can
/// consume the data and transition to FDv1 in the same step.
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

  /// Performs a single poll. Never throws; all failures, including
  /// malformed response bodies, are reported as [StatusResult]s.
  Future<FDv2SourceResult> pollOnce({Selector basis = Selector.empty}) async {
    final RequestorResponse response;
    try {
      response = await _requestor.request(basis: basis);
    } catch (err) {
      // Log only the sanitized form. The raw exception's `toString()` can
      // embed PII (e.g. `http.ClientException` formats as
      // `'ClientException: <msg>, uri=<full-url>'`, and the URL contains
      // the base64url-encoded context in GET mode).
      final sanitized = _describeError(err);
      _logger.warn('Polling request failed: $sanitized');
      return FDv2SourceResults.interrupted(message: sanitized);
    }
    return _processResponse(response);
  }

  FDv2SourceResult _processResponse(RequestorResponse response) {
    // Match `x-ld-fd-fallback` case-insensitively.
    final fdv1Fallback =
        response.headers['x-ld-fd-fallback']?.toLowerCase() == 'true';
    final environmentId = response.headers['x-ld-envid'];

    // 304 Not Modified means the SDK's cached data is confirmed current.
    if (response.status == 304) {
      return ChangeSetResult(
        payload: const Payload(type: PayloadType.none, updates: []),
        environmentId: environmentId,
        freshness: _now(),
        persist: true,
        fdv1Fallback: fdv1Fallback,
      );
    }

    if (response.status >= 400) {
      final message = 'Received unexpected status code: ${response.status}';
      if (isHttpGloballyRecoverable(response.status)) {
        _logger.warn('$message; will retry');
        return FDv2SourceResults.interrupted(
          statusCode: response.status,
          message: message,
          fdv1Fallback: fdv1Fallback,
        );
      }
      _logger.error('$message; will not retry');
      return FDv2SourceResults.terminalError(
        statusCode: response.status,
        message: message,
        fdv1Fallback: fdv1Fallback,
      );
    }

    return _parseBody(
      response,
      environmentId: environmentId,
      fdv1Fallback: fdv1Fallback,
    );
  }

  FDv2SourceResult _parseBody(
    RequestorResponse response, {
    String? environmentId,
    required bool fdv1Fallback,
  }) {
    // The whole parse path is wrapped: jsonDecode plus the structural
    // casts inside FDv2EventsCollection.fromJson and the per-event
    // PutObjectEvent/DeleteObjectEvent/PayloadIntent/etc. fromJson calls
    // can all throw on shapes the protocol types don't accept.
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return FDv2SourceResults.interrupted(
          statusCode: response.status,
          message: 'Polling response was not a JSON object',
          fdv1Fallback: fdv1Fallback,
        );
      }

      final collection = FDv2EventsCollection.fromJson(decoded);
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
              fdv1Fallback: fdv1Fallback,
            );
          case ActionGoodbye(:final reason):
            return FDv2SourceResults.goodbyeResult(
              message: reason,
              fdv1Fallback: fdv1Fallback,
            );
          case ActionServerError(:final reason):
            return FDv2SourceResults.interrupted(
              message: reason,
              fdv1Fallback: fdv1Fallback,
            );
          case ActionError(:final message):
            return FDv2SourceResults.interrupted(
              message: message,
              fdv1Fallback: fdv1Fallback,
            );
          case ActionNone():
            // Continue accumulating events until a payload-transferred or
            // terminal action is reached.
            break;
        }
      }

      // The response had no payload-transferred event. The protocol
      // handler is left in a partial state with nothing to emit, which
      // is a protocol violation for a polling response.
      return FDv2SourceResults.interrupted(
        statusCode: response.status,
        message: 'Polling response did not include a complete payload',
        fdv1Fallback: fdv1Fallback,
      );
    } catch (err, stack) {
      // Log only the type at error level (not the message — `jsonDecode`
      // includes a slice of the offending body, which is server-supplied).
      // The full detail goes to debug, where it is gated by the user's
      // log level.
      _logger.error('Failed to parse polling response (${err.runtimeType})');
      _logger.debug('Polling response parse failure detail: $err\n$stack');
      return FDv2SourceResults.interrupted(
        statusCode: response.status,
        message: 'Polling response body was malformed',
        fdv1Fallback: fdv1Fallback,
      );
    }
  }

  /// Categorizes an exception thrown by the requestor into a fixed,
  /// sanitized message. The raw exception's string form (which can carry
  /// remote address, certificate detail, OS error strings, or — in the
  /// case of `http.ClientException` — the full request URL) is never
  /// echoed to the public status surface or to the warn log.
  ///
  /// Type checks via `is` are minification-safe (unlike substring
  /// matches against `runtimeType.toString()`).
  String _describeError(Object err) {
    if (err is TimeoutException) {
      return 'Polling request timed out';
    }
    if (err is http.ClientException) {
      return 'Network error during polling request';
    }
    // dart:io's TlsException / HandshakeException can't be caught by `is`
    // here without making this file io-only, so fall back to the type
    // name. This is a best-effort label; if minification mangles the
    // type name we land in the default branch below, which is still safe.
    final type = err.runtimeType.toString();
    if (type.contains('Tls') || type.contains('Handshake')) {
      return 'TLS error during polling request';
    }
    return 'Polling request failed';
  }
}
