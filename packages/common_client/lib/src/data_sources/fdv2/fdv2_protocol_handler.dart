import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'fdv2_payload.dart';
import 'fdv2_protocol_types.dart';
import 'selector.dart';

/// Object processors that transform raw JSON objects per kind before
/// they are included in a payload.
typedef ObjProcessor = Map<String, dynamic>? Function(
    Map<String, dynamic> object);

/// The internal state of the protocol handler.
enum ProtocolState {
  /// No server intent has been expressed (initial state).
  inactive,

  /// Currently receiving incremental changes.
  changes,

  /// Currently receiving a full transfer.
  full,
}

/// The kind of protocol error.
enum ProtocolErrorKind {
  unknownEvent,
  missingPayload,
  protocolError,
}

/// Actions returned by the protocol handler after processing an event.
sealed class ProtocolAction {
  const ProtocolAction();
}

/// No special action should be taken.
final class ActionNone extends ProtocolAction {
  const ActionNone();
}

/// A changeset should be applied.
final class ActionPayload extends ProtocolAction {
  final Payload payload;
  const ActionPayload(this.payload);
}

/// An internal protocol error was encountered.
final class ActionError extends ProtocolAction {
  final ProtocolErrorKind kind;
  final String message;
  const ActionError(this.kind, this.message);
}

/// The server intends to disconnect.
final class ActionGoodbye extends ProtocolAction {
  final String reason;
  const ActionGoodbye(this.reason);
}

/// A server-side application error was encountered.
final class ActionServerError extends ProtocolAction {
  final String? id;
  final String reason;
  const ActionServerError(this.reason, {this.id});
}

const _actionNone = ActionNone();

/// Pure FDv2 protocol state machine. Processes a single event at a time and
/// returns an action describing what the caller should do. Contains no I/O
/// or callbacks.
final class FDv2ProtocolHandler {
  final Map<String, ObjProcessor> _objProcessors;
  final LDLogger _logger;

  ProtocolState _state = ProtocolState.inactive;
  PayloadType _tempType = PayloadType.partial;
  List<Update> _tempUpdates = [];

  ProtocolState get state => _state;

  FDv2ProtocolHandler({
    required Map<String, ObjProcessor> objProcessors,
    required LDLogger logger,
  })  : _objProcessors = objProcessors,
        _logger = logger;

  /// Resets the handler to inactive. Should be called when a connection
  /// is reset.
  void reset() {
    _state = ProtocolState.inactive;
    _tempType = PayloadType.partial;
    _tempUpdates = [];
  }

  void _resetAfterEmission() {
    _state = ProtocolState.changes;
    _tempType = PayloadType.partial;
    _tempUpdates = [];
  }

  void _resetAfterError() {
    _tempUpdates = [];
  }

  /// Processes a single FDv2 event and returns an action.
  ProtocolAction processEvent(FDv2Event event) {
    switch (event.event) {
      case FDv2EventTypes.serverIntent:
        return _processServerIntent(
            ServerIntentData.fromJson(event.data));
      case FDv2EventTypes.putObject:
        return _processPutObject(PutObjectEvent.fromJson(event.data));
      case FDv2EventTypes.deleteObject:
        return _processDeleteObject(
            DeleteObjectEvent.fromJson(event.data));
      case FDv2EventTypes.payloadTransferred:
        return _processPayloadTransferred(
            PayloadTransferredEvent.fromJson(event.data));
      case FDv2EventTypes.goodbye:
        return _processGoodbye(GoodbyeEvent.fromJson(event.data));
      case FDv2EventTypes.error:
        return _processError(ServerErrorEvent.fromJson(event.data));
      case FDv2EventTypes.heartbeat:
        return _actionNone;
      default:
        return ActionError(
          ProtocolErrorKind.unknownEvent,
          "Received an unknown event of type '${event.event}'",
        );
    }
  }

  ProtocolAction _processServerIntent(ServerIntentData data) {
    if (data.payloads.isEmpty) {
      return const ActionError(
        ProtocolErrorKind.missingPayload,
        'No payload present in server-intent',
      );
    }

    // Per spec 3.4.2: SDK uses only the first payload.
    final payload = data.payloads[0];

    switch (payload.intentCode) {
      case IntentCode.xferFull:
        _state = ProtocolState.full;
        _tempUpdates = [];
        _tempType = PayloadType.full;
        return _actionNone;
      case IntentCode.xferChanges:
        _state = ProtocolState.changes;
        _tempUpdates = [];
        _tempType = PayloadType.partial;
        return _actionNone;
      case IntentCode.none:
        _state = ProtocolState.changes;
        _tempUpdates = [];
        _tempType = PayloadType.partial;
        return _processIntentNone(payload);
      case null:
        _logger.warn(
            'Unable to process intent code '
            "'${payload.intentCode}'.");
        return _actionNone;
    }
  }

  ProtocolAction _processIntentNone(PayloadIntent intent) {
    if (intent.target == null) {
      _logger.warn(
          "Ignoring 'none' intent with missing target field.");
      return _actionNone;
    }

    return ActionPayload(Payload(
      type: PayloadType.none,
      updates: [],
    ));
  }

  ProtocolAction _processPutObject(PutObjectEvent data) {
    if (_state == ProtocolState.inactive) {
      _logger.warn(
          'Received put-object before server-intent was established. '
          'Ignoring.');
      return _actionNone;
    }

    if (data.kind.isEmpty ||
        data.key.isEmpty ||
        data.version == null ||
        data.object == null) {
      _logger.warn(
          'Ignoring put-object with missing fields: '
          'kind=${data.kind}, key=${data.key}, version=${data.version}');
      return _actionNone;
    }

    final processor = _objProcessors[data.kind];
    if (processor == null) {
      // Per spec 4.1.2: silently ignore objects with unrecognized kind.
      return _actionNone;
    }
    final processed = processor(data.object!);
    if (processed == null) {
      _logger.warn("Unable to process object for kind: '${data.kind}'");
      return _actionNone;
    }

    _tempUpdates.add(Update(
      kind: data.kind,
      key: data.key,
      version: data.version!,
      object: processed,
    ));
    return _actionNone;
  }

  ProtocolAction _processDeleteObject(DeleteObjectEvent data) {
    if (_state == ProtocolState.inactive) {
      _logger.warn(
          'Received delete-object before server-intent was established. '
          'Ignoring.');
      return _actionNone;
    }

    if (data.kind.isEmpty || data.key.isEmpty || data.version == null) {
      _logger.warn(
          'Ignoring delete-object with missing fields: '
          'kind=${data.kind}, key=${data.key}, version=${data.version}');
      return _actionNone;
    }

    if (!_objProcessors.containsKey(data.kind)) {
      // Per spec 4.1.2: silently ignore objects with unrecognized kind.
      return _actionNone;
    }

    _tempUpdates.add(Update(
      kind: data.kind,
      key: data.key,
      version: data.version!,
      deleted: true,
    ));
    return _actionNone;
  }

  ProtocolAction _processPayloadTransferred(PayloadTransferredEvent data) {
    if (_state == ProtocolState.inactive) {
      return const ActionError(
        ProtocolErrorKind.protocolError,
        'A payload-transferred has been received without an intent '
            'having been established.',
      );
    }

    if (data.state.isEmpty || data.version == null) {
      _logger.warn(
          'Ignoring payload-transferred with missing fields: '
          'state=${data.state}, version=${data.version}');
      reset();
      return _actionNone;
    }

    final result = ActionPayload(Payload(
      selector: Selector(state: data.state, version: data.version!),
      type: _tempType,
      updates: _tempUpdates,
    ));

    _resetAfterEmission();
    return result;
  }

  ProtocolAction _processGoodbye(GoodbyeEvent data) {
    _logger.info('Goodbye received from LaunchDarkly: ${data.reason}');
    reset();
    return ActionGoodbye(data.reason);
  }

  ProtocolAction _processError(ServerErrorEvent data) {
    _logger.info(
        'Server error encountered receiving updates: ${data.reason}');
    _resetAfterError();
    return ActionServerError(data.reason, id: data.payloadId);
  }
}
