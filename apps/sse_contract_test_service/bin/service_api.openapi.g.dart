// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_api.openapi.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceStatusResponse _$ServiceStatusResponseFromJson(
        Map<String, dynamic> json) =>
    ServiceStatusResponse(
      capabilities: (json['capabilities'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ServiceStatusResponseToJson(
    ServiceStatusResponse instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('capabilities', instance.capabilities);
  return val;
}

CreateStreamRequestHeaders _$CreateStreamRequestHeadersFromJson(
        Map<String, dynamic> json) =>
    CreateStreamRequestHeaders();

Map<String, dynamic> _$CreateStreamRequestHeadersToJson(
        CreateStreamRequestHeaders instance) =>
    <String, dynamic>{};

CreateStreamRequest _$CreateStreamRequestFromJson(Map<String, dynamic> json) =>
    CreateStreamRequest(
      streamUrl: json['streamUrl'] as String?,
      callbackUrl: json['callbackUrl'] as String?,
      tag: json['tag'] as String?,
      initialDelayMs: json['initialDelayMs'] as int?,
      readTimeoutMs: json['readTimeoutMs'] as int?,
      lastEventId: json['lastEventId'] as String?,
      headers: json['headers'] == null
          ? null
          : CreateStreamRequestHeaders.fromJson(
              json['headers'] as Map<String, dynamic>),
      method: json['method'] as String?,
      body: json['body'] as String?,
    );

Map<String, dynamic> _$CreateStreamRequestToJson(CreateStreamRequest instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('streamUrl', instance.streamUrl);
  writeNotNull('callbackUrl', instance.callbackUrl);
  writeNotNull('tag', instance.tag);
  writeNotNull('initialDelayMs', instance.initialDelayMs);
  writeNotNull('readTimeoutMs', instance.readTimeoutMs);
  writeNotNull('lastEventId', instance.lastEventId);
  writeNotNull('headers', instance.headers);
  writeNotNull('method', instance.method);
  writeNotNull('body', instance.body);
  return val;
}
