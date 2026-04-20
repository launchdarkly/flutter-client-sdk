/// FDv2 wire protocol event type names.
abstract final class FDv2EventTypes {
  static const String serverIntent = 'server-intent';
  static const String putObject = 'put-object';
  static const String deleteObject = 'delete-object';
  static const String payloadTransferred = 'payload-transferred';
  static const String goodbye = 'goodbye';
  static const String error = 'error';
  static const String heartbeat = 'heart-beat';
}

/// The intent code from a server-intent payload entry.
enum IntentCode {
  transferFull('xfer-full'),
  transferChanges('xfer-changes'),
  none('none');

  final String wireValue;
  const IntentCode(this.wireValue);

  static IntentCode? fromWire(String? value) {
    if (value == null) return null;
    for (final code in values) {
      if (code.wireValue == value) return code;
    }
    return null;
  }
}

/// A single payload entry within a server-intent event.
final class PayloadIntent {
  final String id;

  /// The target version. Null if the field was missing from the JSON.
  final int? target;

  /// The intent code. Null if the wire value was unrecognized or missing.
  final IntentCode? intentCode;

  final String reason;

  const PayloadIntent({
    required this.id,
    this.target,
    this.intentCode,
    required this.reason,
  });

  factory PayloadIntent.fromJson(Map<String, dynamic> json) {
    return PayloadIntent(
      id: json['id'] as String? ?? '',
      target: (json['target'] as num?)?.toInt(),
      intentCode: IntentCode.fromWire(json['intentCode'] as String?),
      reason: json['reason'] as String? ?? '',
    );
  }
}

/// The data payload of a server-intent event.
final class ServerIntentData {
  final List<PayloadIntent> payloads;

  const ServerIntentData({required this.payloads});

  factory ServerIntentData.fromJson(Map<String, dynamic> json) {
    final payloadsList = json['payloads'] as List<dynamic>?;
    return ServerIntentData(
      payloads: payloadsList
              ?.map((e) => PayloadIntent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// A put-object event: upsert a single item.
final class PutObjectEvent {
  final String kind;
  final String key;

  /// Null if the field was missing from the JSON.
  final int? version;

  /// Null if the field was missing from the JSON.
  final Map<String, dynamic>? object;

  const PutObjectEvent({
    required this.kind,
    required this.key,
    this.version,
    this.object,
  });

  factory PutObjectEvent.fromJson(Map<String, dynamic> json) {
    return PutObjectEvent(
      kind: json['kind'] as String? ?? '',
      key: json['key'] as String? ?? '',
      version: (json['version'] as num?)?.toInt(),
      object: json['object'] as Map<String, dynamic>?,
    );
  }
}

/// A delete-object event: remove a single item.
final class DeleteObjectEvent {
  final String kind;
  final String key;

  /// Null if the field was missing from the JSON.
  final int? version;

  const DeleteObjectEvent({
    required this.kind,
    required this.key,
    this.version,
  });

  factory DeleteObjectEvent.fromJson(Map<String, dynamic> json) {
    return DeleteObjectEvent(
      kind: json['kind'] as String? ?? '',
      key: json['key'] as String? ?? '',
      version: (json['version'] as num?)?.toInt(),
    );
  }
}

/// A payload-transferred event marking the end of a transfer batch.
final class PayloadTransferredEvent {
  final String state;

  /// Null if the field was missing from the JSON.
  final int? version;

  const PayloadTransferredEvent({
    required this.state,
    this.version,
  });

  factory PayloadTransferredEvent.fromJson(Map<String, dynamic> json) {
    return PayloadTransferredEvent(
      state: json['state'] as String? ?? '',
      version: (json['version'] as num?)?.toInt(),
    );
  }
}

/// A goodbye event indicating the server intends to disconnect.
final class GoodbyeEvent {
  final String reason;
  final bool silent;

  const GoodbyeEvent({
    required this.reason,
    this.silent = false,
  });

  factory GoodbyeEvent.fromJson(Map<String, dynamic> json) {
    return GoodbyeEvent(
      reason: json['reason'] as String? ?? '',
      silent: json['silent'] as bool? ?? false,
    );
  }
}

/// An error event from the server.
final class ServerErrorEvent {
  final String? payloadId;
  final String reason;

  const ServerErrorEvent({
    this.payloadId,
    required this.reason,
  });

  factory ServerErrorEvent.fromJson(Map<String, dynamic> json) {
    return ServerErrorEvent(
      payloadId: json['payload_id'] as String?,
      reason: json['reason'] as String? ?? '',
    );
  }
}

/// A single FDv2 event as received over SSE or within a polling response.
final class FDv2Event {
  final String event;
  final Map<String, dynamic> data;

  const FDv2Event({required this.event, required this.data});

  factory FDv2Event.fromJson(Map<String, dynamic> json) {
    return FDv2Event(
      event: json['event'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// A collection of FDv2 events as returned from a polling response.
final class FDv2EventsCollection {
  final List<FDv2Event> events;

  const FDv2EventsCollection({required this.events});

  factory FDv2EventsCollection.fromJson(Map<String, dynamic> json) {
    final eventsList = json['events'] as List<dynamic>? ?? const [];
    return FDv2EventsCollection(
      events: eventsList
          .map((e) => FDv2Event.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
