// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'callback_api.openapi.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PostCallbackEvent _$PostCallbackEventFromJson(Map<String, dynamic> json) =>
    PostCallbackEvent(
      type: json['type'] as String?,
      data: json['data'] as String?,
      id: json['id'] as String?,
    );

Map<String, dynamic> _$PostCallbackEventToJson(PostCallbackEvent instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('type', instance.type);
  writeNotNull('data', instance.data);
  writeNotNull('id', instance.id);
  return val;
}

PostCallback _$PostCallbackFromJson(Map<String, dynamic> json) => PostCallback(
      kind: json['kind'] as String?,
      comment: json['comment'] as String?,
      event: json['event'] == null
          ? null
          : PostCallbackEvent.fromJson(json['event'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PostCallbackToJson(PostCallback instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('kind', instance.kind);
  writeNotNull('comment', instance.comment);
  writeNotNull('event', instance.event);
  return val;
}
