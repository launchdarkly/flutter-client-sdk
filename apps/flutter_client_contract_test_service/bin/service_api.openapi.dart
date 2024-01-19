// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: prefer_initializing_formals, no_leading_underscores_for_library_prefixes, library_private_types_in_public_api

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:openapi_base/openapi_base.dart';
part 'service_api.openapi.g.dart';

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestIdentifyEventContext implements OpenApiContent {
  RequestIdentifyEventContext();

  factory RequestIdentifyEventContext.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestIdentifyEventContextFromJson(jsonMap)
        .._additionalProperties.addEntries(
            jsonMap.entries.where((e) => !const <String>{}.contains(e.key)));

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() => Map.from(_additionalProperties)
    ..addAll(_$RequestIdentifyEventContextToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  Object operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestIdentifyEvent implements OpenApiContent {
  RequestIdentifyEvent({this.context});

  factory RequestIdentifyEvent.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestIdentifyEventFromJson(jsonMap);

  @JsonKey(
    name: 'context',
    includeIfNull: false,
  )
  final RequestIdentifyEventContext? context;

  Map<String, dynamic> toJson() => _$RequestIdentifyEventToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestEvaluateContext implements OpenApiContent {
  RequestEvaluateContext();

  factory RequestEvaluateContext.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestEvaluateContextFromJson(jsonMap)
        .._additionalProperties.addEntries(
            jsonMap.entries.where((e) => !const <String>{}.contains(e.key)));

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() => Map.from(_additionalProperties)
    ..addAll(_$RequestEvaluateContextToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  Object operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestEvaluateUser implements OpenApiContent {
  RequestEvaluateUser();

  factory RequestEvaluateUser.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestEvaluateUserFromJson(jsonMap)
        .._additionalProperties.addEntries(
            jsonMap.entries.where((e) => !const <String>{}.contains(e.key)));

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() => Map.from(_additionalProperties)
    ..addAll(_$RequestEvaluateUserToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  Object operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestEvaluate implements OpenApiContent {
  RequestEvaluate({
    this.flagKey,
    this.context,
    this.user,
    this.valueType,
    this.detail,
  });

  factory RequestEvaluate.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestEvaluateFromJson(jsonMap)
        .._additionalProperties
            .addEntries(jsonMap.entries.where((e) => !const <String>{
                  'flagKey',
                  'context',
                  'user',
                  'valueType',
                  'detail',
                }.contains(e.key)));

  @JsonKey(
    name: 'flagKey',
    includeIfNull: false,
  )
  final String? flagKey;

  @JsonKey(
    name: 'context',
    includeIfNull: false,
  )
  final RequestEvaluateContext? context;

  @JsonKey(
    name: 'user',
    includeIfNull: false,
  )
  final RequestEvaluateUser? user;

  @JsonKey(
    name: 'valueType',
    includeIfNull: false,
  )
  final String? valueType;

  @JsonKey(
    name: 'detail',
    includeIfNull: false,
  )
  final bool? detail;

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() =>
      Map.from(_additionalProperties)..addAll(_$RequestEvaluateToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  Object operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestEvaluateAllContext implements OpenApiContent {
  RequestEvaluateAllContext();

  factory RequestEvaluateAllContext.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestEvaluateAllContextFromJson(jsonMap)
        .._additionalProperties.addEntries(
            jsonMap.entries.where((e) => !const <String>{}.contains(e.key)));

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() => Map.from(_additionalProperties)
    ..addAll(_$RequestEvaluateAllContextToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  Object operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestEvaluateAllUser implements OpenApiContent {
  RequestEvaluateAllUser();

  factory RequestEvaluateAllUser.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestEvaluateAllUserFromJson(jsonMap)
        .._additionalProperties.addEntries(
            jsonMap.entries.where((e) => !const <String>{}.contains(e.key)));

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() => Map.from(_additionalProperties)
    ..addAll(_$RequestEvaluateAllUserToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  Object operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestEvaluateAll implements OpenApiContent {
  RequestEvaluateAll({
    this.context,
    this.user,
    this.withReasons,
    this.clientSideOnly,
    this.detailsOnlyForTrackedFlags,
  });

  factory RequestEvaluateAll.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestEvaluateAllFromJson(jsonMap);

  @JsonKey(
    name: 'context',
    includeIfNull: false,
  )
  final RequestEvaluateAllContext? context;

  @JsonKey(
    name: 'user',
    includeIfNull: false,
  )
  final RequestEvaluateAllUser? user;

  @JsonKey(
    name: 'withReasons',
    includeIfNull: false,
  )
  final bool? withReasons;

  @JsonKey(
    name: 'clientSideOnly',
    includeIfNull: false,
  )
  final bool? clientSideOnly;

  @JsonKey(
    name: 'detailsOnlyForTrackedFlags',
    includeIfNull: false,
  )
  final bool? detailsOnlyForTrackedFlags;

  Map<String, dynamic> toJson() => _$RequestEvaluateAllToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestCustomEvent implements OpenApiContent {
  RequestCustomEvent({
    this.eventKey,
    this.omitNullData,
    this.metricValue,
  });

  factory RequestCustomEvent.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestCustomEventFromJson(jsonMap)
        .._additionalProperties
            .addEntries(jsonMap.entries.where((e) => !const <String>{
                  'eventKey',
                  'omitNullData',
                  'metricValue',
                }.contains(e.key)));

  @JsonKey(
    name: 'eventKey',
    includeIfNull: false,
  )
  final String? eventKey;

  @JsonKey(
    name: 'omitNullData',
    includeIfNull: false,
  )
  final bool? omitNullData;

  @JsonKey(
    name: 'metricValue',
    includeIfNull: false,
  )
  final num? metricValue;

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() =>
      Map.from(_additionalProperties)..addAll(_$RequestCustomEventToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  Object operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class BuildContext implements OpenApiContent {
  BuildContext();

  factory BuildContext.fromJson(Map<String, dynamic> jsonMap) =>
      _$BuildContextFromJson(jsonMap)
        .._additionalProperties.addEntries(
            jsonMap.entries.where((e) => !const <String>{}.contains(e.key)));

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() =>
      Map.from(_additionalProperties)..addAll(_$BuildContextToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  dynamic operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class SingleOrMultiBuildContext implements OpenApiContent {
  SingleOrMultiBuildContext({
    this.single,
    this.multi,
  });

  factory SingleOrMultiBuildContext.fromJson(Map<String, dynamic> jsonMap) =>
      _$SingleOrMultiBuildContextFromJson(jsonMap);

  @JsonKey(
    name: 'single',
    includeIfNull: false,
  )
  final BuildContext? single;

  @JsonKey(
    name: 'multi',
    includeIfNull: false,
  )
  final List<BuildContext>? multi;

  Map<String, dynamic> toJson() => _$SingleOrMultiBuildContextToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestContextConvert implements OpenApiContent {
  RequestContextConvert({this.input});

  factory RequestContextConvert.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestContextConvertFromJson(jsonMap);

  @JsonKey(
    name: 'input',
    includeIfNull: false,
  )
  final String? input;

  Map<String, dynamic> toJson() => _$RequestContextConvertToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class RequestContextComparison implements OpenApiContent {
  RequestContextComparison({
    this.context1,
    this.context2,
  });

  factory RequestContextComparison.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestContextComparisonFromJson(jsonMap);

  @JsonKey(
    name: 'context1',
    includeIfNull: false,
  )
  final SingleOrMultiBuildContext? context1;

  @JsonKey(
    name: 'context2',
    includeIfNull: false,
  )
  final SingleOrMultiBuildContext? context2;

  Map<String, dynamic> toJson() => _$RequestContextComparisonToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class Request implements OpenApiContent {
  Request({
    this.command,
    this.identifyEvent,
    this.evaluate,
    this.evaluateAll,
    this.customEvent,
    this.contextBuild,
    this.contextConvert,
    this.contextComparison,
  });

  factory Request.fromJson(Map<String, dynamic> jsonMap) =>
      _$RequestFromJson(jsonMap);

  @JsonKey(
    name: 'command',
    includeIfNull: false,
  )
  final String? command;

  @JsonKey(
    name: 'identifyEvent',
    includeIfNull: false,
  )
  final RequestIdentifyEvent? identifyEvent;

  @JsonKey(
    name: 'evaluate',
    includeIfNull: false,
  )
  final RequestEvaluate? evaluate;

  @JsonKey(
    name: 'evaluateAll',
    includeIfNull: false,
  )
  final RequestEvaluateAll? evaluateAll;

  @JsonKey(
    name: 'customEvent',
    includeIfNull: false,
  )
  final RequestCustomEvent? customEvent;

  @JsonKey(
    name: 'contextBuild',
    includeIfNull: false,
  )
  final SingleOrMultiBuildContext? contextBuild;

  @JsonKey(
    name: 'contextConvert',
    includeIfNull: false,
  )
  final RequestContextConvert? contextConvert;

  @JsonKey(
    name: 'contextComparison',
    includeIfNull: false,
  )
  final RequestContextComparison? contextComparison;

  Map<String, dynamic> toJson() => _$RequestToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class Response implements OpenApiContent {
  Response();

  factory Response.fromJson(Map<String, dynamic> jsonMap) =>
      _$ResponseFromJson(jsonMap)
        .._additionalProperties.addEntries(
            jsonMap.entries.where((e) => !const <String>{}.contains(e.key)));

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() =>
      Map.from(_additionalProperties)..addAll(_$ResponseToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  Object operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class GetResponseBody200 implements OpenApiContent {
  GetResponseBody200({
    this.name,
    this.clientVersion,
    this.capabilities,
  });

  factory GetResponseBody200.fromJson(Map<String, dynamic> jsonMap) =>
      _$GetResponseBody200FromJson(jsonMap);

  @JsonKey(
    name: 'name',
    includeIfNull: false,
  )
  final String? name;

  @JsonKey(
    name: 'clientVersion',
    includeIfNull: false,
  )
  final String? clientVersion;

  @JsonKey(
    name: 'capabilities',
    includeIfNull: false,
  )
  final List<String>? capabilities;

  Map<String, dynamic> toJson() => _$GetResponseBody200ToJson(this);

  @override
  String toString() => toJson().toString();
}

class _GetResponse200 extends GetResponse implements OpenApiResponseBodyJson {
  /// OK
  _GetResponse200.response200(this.body)
      : status = 200,
        bodyJson = body.toJson();

  @override
  final int status;

  final GetResponseBody200 body;

  @override
  final Map<String, dynamic> bodyJson;

  @override
  final OpenApiContentType contentType =
      OpenApiContentType.parse('application/json');

  @override
  Map<String, Object?> propertiesToString() => {
        'status': status,
        'body': body,
        'bodyJson': bodyJson,
        'contentType': contentType,
      };
}

abstract class GetResponse extends OpenApiResponse
    implements HasSuccessResponse<GetResponseBody200> {
  GetResponse();

  /// OK
  factory GetResponse.response200(GetResponseBody200 body) =>
      _GetResponse200.response200(body);

  void map({required ResponseMap<_GetResponse200> on200}) {
    if (this is _GetResponse200) {
      on200((this as _GetResponse200));
    } else {
      throw StateError('Invalid instance type $this');
    }
  }

  /// status 200:  OK
  @override
  GetResponseBody200 requireSuccess() {
    if (this is _GetResponse200) {
      return (this as _GetResponse200).body;
    } else {
      throw StateError('Expected success response, but got $this');
    }
  }
}

class _PostResponse201 extends PostResponse {
  /// Successful creation
  _PostResponse201.response201() : status = 201;

  @override
  final int status;

  @override
  final OpenApiContentType? contentType = null;

  @override
  Map<String, Object?> propertiesToString() => {
        'status': status,
        'contentType': contentType,
      };
}

class _PostResponse400 extends PostResponse {
  /// Invalid parameters
  _PostResponse400.response400() : status = 400;

  @override
  final int status;

  @override
  final OpenApiContentType? contentType = null;

  @override
  Map<String, Object?> propertiesToString() => {
        'status': status,
        'contentType': contentType,
      };
}

abstract class PostResponse extends OpenApiResponse
    implements HasSuccessResponse<void> {
  PostResponse();

  /// Successful creation
  factory PostResponse.response201() => _PostResponse201.response201();

  /// Invalid parameters
  factory PostResponse.response400() => _PostResponse400.response400();

  void map({
    required ResponseMap<_PostResponse201> on201,
    required ResponseMap<_PostResponse400> on400,
  }) {
    if (this is _PostResponse201) {
      on201((this as _PostResponse201));
    } else if (this is _PostResponse400) {
      on400((this as _PostResponse400));
    } else {
      throw StateError('Invalid instance type $this');
    }
  }

  /// status 201:  Successful creation
  @override
  void requireSuccess() {
    if (this is _PostResponse201) {
      return;
    } else {
      throw StateError('Expected success response, but got $this');
    }
  }
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchemaConfigurationServiceEndpoints implements OpenApiContent {
  PostSchemaConfigurationServiceEndpoints({
    this.streaming,
    this.polling,
    this.events,
  });

  factory PostSchemaConfigurationServiceEndpoints.fromJson(
          Map<String, dynamic> jsonMap) =>
      _$PostSchemaConfigurationServiceEndpointsFromJson(jsonMap);

  @JsonKey(
    name: 'streaming',
    includeIfNull: false,
  )
  final String? streaming;

  @JsonKey(
    name: 'polling',
    includeIfNull: false,
  )
  final String? polling;

  @JsonKey(
    name: 'events',
    includeIfNull: false,
  )
  final String? events;

  Map<String, dynamic> toJson() =>
      _$PostSchemaConfigurationServiceEndpointsToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchemaConfigurationStreaming implements OpenApiContent {
  PostSchemaConfigurationStreaming({
    this.baseUri,
    this.initialRetryDelayMs,
    this.filter,
  });

  factory PostSchemaConfigurationStreaming.fromJson(
          Map<String, dynamic> jsonMap) =>
      _$PostSchemaConfigurationStreamingFromJson(jsonMap);

  /// The base URI for the streaming service.
  @JsonKey(
    name: 'baseUri',
    includeIfNull: false,
  )
  final String? baseUri;

  /// The initial stream retry delay in milliseconds.
  @JsonKey(
    name: 'initialRetryDelayMs',
    includeIfNull: false,
  )
  final num? initialRetryDelayMs;

  /// The key for a filtered environment.
  @JsonKey(
    name: 'filter',
    includeIfNull: false,
  )
  final String? filter;

  Map<String, dynamic> toJson() =>
      _$PostSchemaConfigurationStreamingToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchemaConfigurationPolling implements OpenApiContent {
  PostSchemaConfigurationPolling({
    this.baseUri,
    this.pollIntervalMs,
    this.filter,
  });

  factory PostSchemaConfigurationPolling.fromJson(
          Map<String, dynamic> jsonMap) =>
      _$PostSchemaConfigurationPollingFromJson(jsonMap);

  /// The base URI for the polling service.
  @JsonKey(
    name: 'baseUri',
    includeIfNull: false,
  )
  final String? baseUri;

  /// The polling interval in milliseconds.
  @JsonKey(
    name: 'pollIntervalMs',
    includeIfNull: false,
  )
  final num? pollIntervalMs;

  /// The key for a filtered environment.
  @JsonKey(
    name: 'filter',
    includeIfNull: false,
  )
  final String? filter;

  Map<String, dynamic> toJson() => _$PostSchemaConfigurationPollingToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchemaConfigurationEvents implements OpenApiContent {
  PostSchemaConfigurationEvents({
    this.baseUri,
    this.capacity,
    this.enableDiagnostics,
    this.allAttributesPrivate,
    this.globalPrivateAttributes,
    this.flushIntervalMs,
  });

  factory PostSchemaConfigurationEvents.fromJson(
          Map<String, dynamic> jsonMap) =>
      _$PostSchemaConfigurationEventsFromJson(jsonMap);

  @JsonKey(
    name: 'baseUri',
    includeIfNull: false,
  )
  final String? baseUri;

  @JsonKey(
    name: 'capacity',
    includeIfNull: false,
  )
  final num? capacity;

  @JsonKey(
    name: 'enableDiagnostics',
    includeIfNull: false,
  )
  final bool? enableDiagnostics;

  @JsonKey(
    name: 'allAttributesPrivate',
    includeIfNull: false,
  )
  final bool? allAttributesPrivate;

  @JsonKey(
    name: 'globalPrivateAttributes',
    includeIfNull: false,
  )
  final List<String>? globalPrivateAttributes;

  @JsonKey(
    name: 'flushIntervalMs',
    includeIfNull: false,
  )
  final num? flushIntervalMs;

  Map<String, dynamic> toJson() => _$PostSchemaConfigurationEventsToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchemaConfigurationBigSegments implements OpenApiContent {
  PostSchemaConfigurationBigSegments({
    this.callbackUri,
    this.userCacheSize,
    this.userCacheTimeMs,
    this.statusPollIntervalMS,
    this.staleAfterMs,
  });

  factory PostSchemaConfigurationBigSegments.fromJson(
          Map<String, dynamic> jsonMap) =>
      _$PostSchemaConfigurationBigSegmentsFromJson(jsonMap);

  @JsonKey(
    name: 'callbackUri',
    includeIfNull: false,
  )
  final String? callbackUri;

  @JsonKey(
    name: 'userCacheSize',
    includeIfNull: false,
  )
  final num? userCacheSize;

  @JsonKey(
    name: 'userCacheTimeMs',
    includeIfNull: false,
  )
  final num? userCacheTimeMs;

  @JsonKey(
    name: 'statusPollIntervalMS',
    includeIfNull: false,
  )
  final num? statusPollIntervalMS;

  @JsonKey(
    name: 'staleAfterMs',
    includeIfNull: false,
  )
  final num? staleAfterMs;

  Map<String, dynamic> toJson() =>
      _$PostSchemaConfigurationBigSegmentsToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchemaConfigurationTags implements OpenApiContent {
  PostSchemaConfigurationTags({
    this.applicationId,
    this.applicationVersion,
  });

  factory PostSchemaConfigurationTags.fromJson(Map<String, dynamic> jsonMap) =>
      _$PostSchemaConfigurationTagsFromJson(jsonMap);

  @JsonKey(
    name: 'applicationId',
    includeIfNull: false,
  )
  final String? applicationId;

  @JsonKey(
    name: 'applicationVersion',
    includeIfNull: false,
  )
  final String? applicationVersion;

  Map<String, dynamic> toJson() => _$PostSchemaConfigurationTagsToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchemaConfigurationClientSideInitialContext
    implements OpenApiContent {
  PostSchemaConfigurationClientSideInitialContext();

  factory PostSchemaConfigurationClientSideInitialContext.fromJson(
          Map<String, dynamic> jsonMap) =>
      _$PostSchemaConfigurationClientSideInitialContextFromJson(jsonMap)
        .._additionalProperties.addEntries(
            jsonMap.entries.where((e) => !const <String>{}.contains(e.key)));

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() => Map.from(_additionalProperties)
    ..addAll(_$PostSchemaConfigurationClientSideInitialContextToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  Object operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchemaConfigurationClientSideInitialUser implements OpenApiContent {
  PostSchemaConfigurationClientSideInitialUser();

  factory PostSchemaConfigurationClientSideInitialUser.fromJson(
          Map<String, dynamic> jsonMap) =>
      _$PostSchemaConfigurationClientSideInitialUserFromJson(jsonMap)
        .._additionalProperties.addEntries(
            jsonMap.entries.where((e) => !const <String>{}.contains(e.key)));

  final Map<String, dynamic> _additionalProperties = <String, dynamic>{};

  Map<String, dynamic> toJson() => Map.from(_additionalProperties)
    ..addAll(_$PostSchemaConfigurationClientSideInitialUserToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    Object value,
  ) =>
      _additionalProperties[key] = value;

  Object operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchemaConfigurationClientSide implements OpenApiContent {
  PostSchemaConfigurationClientSide({
    this.initialContext,
    this.initialUser,
    this.evaluationReasons,
    this.useReport,
  });

  factory PostSchemaConfigurationClientSide.fromJson(
          Map<String, dynamic> jsonMap) =>
      _$PostSchemaConfigurationClientSideFromJson(jsonMap);

  @JsonKey(
    name: 'initialContext',
    includeIfNull: false,
  )
  final PostSchemaConfigurationClientSideInitialContext? initialContext;

  @JsonKey(
    name: 'initialUser',
    includeIfNull: false,
  )
  final PostSchemaConfigurationClientSideInitialUser? initialUser;

  @JsonKey(
    name: 'evaluationReasons',
    includeIfNull: false,
  )
  final bool? evaluationReasons;

  @JsonKey(
    name: 'useReport',
    includeIfNull: false,
  )
  final bool? useReport;

  Map<String, dynamic> toJson() =>
      _$PostSchemaConfigurationClientSideToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchemaConfiguration implements OpenApiContent {
  PostSchemaConfiguration({
    this.credential,
    this.startWaitTimeMs,
    this.initCanFail,
    this.serviceEndpoints,
    this.streaming,
    this.polling,
    this.events,
    this.bigSegments,
    this.tags,
    this.clientSide,
  });

  factory PostSchemaConfiguration.fromJson(Map<String, dynamic> jsonMap) =>
      _$PostSchemaConfigurationFromJson(jsonMap);

  /// The SDK key for server-side SDKs, mobile key for mobile SDKs, or environment ID for JS-based SDKs.
  @JsonKey(
    name: 'credential',
    includeIfNull: false,
  )
  final String? credential;

  /// The initialization timeout in milliseconds.
  @JsonKey(
    name: 'startWaitTimeMs',
    includeIfNull: false,
  )
  final num? startWaitTimeMs;

  /// If true, the test service should not return an error for client initialization failing.
  @JsonKey(
    name: 'initCanFail',
    includeIfNull: false,
  )
  final bool? initCanFail;

  @JsonKey(
    name: 'serviceEndpoints',
    includeIfNull: false,
  )
  final PostSchemaConfigurationServiceEndpoints? serviceEndpoints;

  @JsonKey(
    name: 'streaming',
    includeIfNull: false,
  )
  final PostSchemaConfigurationStreaming? streaming;

  @JsonKey(
    name: 'polling',
    includeIfNull: false,
  )
  final PostSchemaConfigurationPolling? polling;

  @JsonKey(
    name: 'events',
    includeIfNull: false,
  )
  final PostSchemaConfigurationEvents? events;

  @JsonKey(
    name: 'bigSegments',
    includeIfNull: false,
  )
  final PostSchemaConfigurationBigSegments? bigSegments;

  @JsonKey(
    name: 'tags',
    includeIfNull: false,
  )
  final PostSchemaConfigurationTags? tags;

  @JsonKey(
    name: 'clientSide',
    includeIfNull: false,
  )
  final PostSchemaConfigurationClientSide? clientSide;

  Map<String, dynamic> toJson() => _$PostSchemaConfigurationToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostSchema implements OpenApiContent {
  PostSchema({
    this.tag,
    this.configuration,
  });

  factory PostSchema.fromJson(Map<String, dynamic> jsonMap) =>
      _$PostSchemaFromJson(jsonMap);

  @JsonKey(
    name: 'tag',
    includeIfNull: false,
  )
  final String? tag;

  @JsonKey(
    name: 'configuration',
    includeIfNull: false,
  )
  final PostSchemaConfiguration? configuration;

  Map<String, dynamic> toJson() => _$PostSchemaToJson(this);

  @override
  String toString() => toJson().toString();
}

class _DeleteResponse200 extends DeleteResponse {
  /// Service stopped
  _DeleteResponse200.response200() : status = 200;

  @override
  final int status;

  @override
  final OpenApiContentType? contentType = null;

  @override
  Map<String, Object?> propertiesToString() => {
        'status': status,
        'contentType': contentType,
      };
}

abstract class DeleteResponse extends OpenApiResponse
    implements HasSuccessResponse<void> {
  DeleteResponse();

  /// Service stopped
  factory DeleteResponse.response200() => _DeleteResponse200.response200();

  void map({required ResponseMap<_DeleteResponse200> on200}) {
    if (this is _DeleteResponse200) {
      on200((this as _DeleteResponse200));
    } else {
      throw StateError('Invalid instance type $this');
    }
  }

  /// status 200:  Service stopped
  @override
  void requireSuccess() {
    if (this is _DeleteResponse200) {
      return;
    } else {
      throw StateError('Expected success response, but got $this');
    }
  }
}

class _ClientIdPostResponse200 extends ClientIdPostResponse
    implements OpenApiResponseBodyJson {
  /// Success
  _ClientIdPostResponse200.response200(this.body)
      : status = 200,
        bodyJson = body.toJson();

  @override
  final int status;

  final Response body;

  @override
  final Map<String, dynamic> bodyJson;

  @override
  final OpenApiContentType contentType =
      OpenApiContentType.parse('application/json');

  @override
  Map<String, Object?> propertiesToString() => {
        'status': status,
        'body': body,
        'bodyJson': bodyJson,
        'contentType': contentType,
      };
}

class _ClientIdPostResponse404 extends ClientIdPostResponse {
  /// Not found
  _ClientIdPostResponse404.response404() : status = 404;

  @override
  final int status;

  @override
  final OpenApiContentType? contentType = null;

  @override
  Map<String, Object?> propertiesToString() => {
        'status': status,
        'contentType': contentType,
      };
}

abstract class ClientIdPostResponse extends OpenApiResponse
    implements HasSuccessResponse<Response> {
  ClientIdPostResponse();

  /// Success
  factory ClientIdPostResponse.response200(Response body) =>
      _ClientIdPostResponse200.response200(body);

  /// Not found
  factory ClientIdPostResponse.response404() =>
      _ClientIdPostResponse404.response404();

  void map({
    required ResponseMap<_ClientIdPostResponse200> on200,
    required ResponseMap<_ClientIdPostResponse404> on404,
  }) {
    if (this is _ClientIdPostResponse200) {
      on200((this as _ClientIdPostResponse200));
    } else if (this is _ClientIdPostResponse404) {
      on404((this as _ClientIdPostResponse404));
    } else {
      throw StateError('Invalid instance type $this');
    }
  }

  /// status 200:  Success
  @override
  Response requireSuccess() {
    if (this is _ClientIdPostResponse200) {
      return (this as _ClientIdPostResponse200).body;
    } else {
      throw StateError('Expected success response, but got $this');
    }
  }
}

class _ClientIdDeleteResponse200 extends ClientIdDeleteResponse {
  /// OK
  _ClientIdDeleteResponse200.response200() : status = 200;

  @override
  final int status;

  @override
  final OpenApiContentType? contentType = null;

  @override
  Map<String, Object?> propertiesToString() => {
        'status': status,
        'contentType': contentType,
      };
}

class _ClientIdDeleteResponse404 extends ClientIdDeleteResponse {
  /// Client not found
  _ClientIdDeleteResponse404.response404() : status = 404;

  @override
  final int status;

  @override
  final OpenApiContentType? contentType = null;

  @override
  Map<String, Object?> propertiesToString() => {
        'status': status,
        'contentType': contentType,
      };
}

abstract class ClientIdDeleteResponse extends OpenApiResponse
    implements HasSuccessResponse<void> {
  ClientIdDeleteResponse();

  /// OK
  factory ClientIdDeleteResponse.response200() =>
      _ClientIdDeleteResponse200.response200();

  /// Client not found
  factory ClientIdDeleteResponse.response404() =>
      _ClientIdDeleteResponse404.response404();

  void map({
    required ResponseMap<_ClientIdDeleteResponse200> on200,
    required ResponseMap<_ClientIdDeleteResponse404> on404,
  }) {
    if (this is _ClientIdDeleteResponse200) {
      on200((this as _ClientIdDeleteResponse200));
    } else if (this is _ClientIdDeleteResponse404) {
      on404((this as _ClientIdDeleteResponse404));
    } else {
      throw StateError('Invalid instance type $this');
    }
  }

  /// status 200:  OK
  @override
  void requireSuccess() {
    if (this is _ClientIdDeleteResponse200) {
      return;
    } else {
      throw StateError('Expected success response, but got $this');
    }
  }
}

abstract class SdkTestApi implements ApiEndpoint {
  /// Status resource
  /// get: /
  Future<GetResponse> Get();

  /// Create SDK client
  /// post: /
  Future<PostResponse> Post(PostSchema body);

  /// Stop test service
  /// delete: /
  Future<DeleteResponse> Delete();

  /// post: /client/{id}
  Future<ClientIdPostResponse> clientIdPost(
    Request body, {
    required int id,
  });

  /// Delete client
  /// delete: /client/{id}
  Future<ClientIdDeleteResponse> clientIdDelete({required int id});
}

abstract class SdkTestApiClient implements OpenApiClient {
  factory SdkTestApiClient(
    Uri baseUri,
    OpenApiRequestSender requestSender,
  ) =>
      _SdkTestApiClientImpl._(
        baseUri,
        requestSender,
      );

  /// Status resource
  /// get: /
  ///
  Future<GetResponse> Get();

  /// Create SDK client
  /// post: /
  ///
  Future<PostResponse> Post(PostSchema body);

  /// Stop test service
  /// delete: /
  ///
  Future<DeleteResponse> Delete();

  /// post: /client/{id}
  ///
  Future<ClientIdPostResponse> clientIdPost(
    Request body, {
    required int id,
  });

  /// Delete client
  /// delete: /client/{id}
  ///
  Future<ClientIdDeleteResponse> clientIdDelete({required int id});
}

class _SdkTestApiClientImpl extends OpenApiClientBase
    implements SdkTestApiClient {
  _SdkTestApiClientImpl._(
    this.baseUri,
    this.requestSender,
  );

  @override
  final Uri baseUri;

  @override
  final OpenApiRequestSender requestSender;

  /// Status resource
  /// get: /
  ///
  @override
  Future<GetResponse> Get() async {
    final request = OpenApiClientRequest(
      'get',
      '/',
      [],
    );
    return await sendRequest(
      request,
      {
        '200': (OpenApiClientResponse response) async =>
            _GetResponse200.response200(
                GetResponseBody200.fromJson(await response.responseBodyJson()))
      },
    );
  }

  /// Create SDK client
  /// post: /
  ///
  @override
  Future<PostResponse> Post(PostSchema body) async {
    final request = OpenApiClientRequest(
      'post',
      '/',
      [],
    );
    request.setHeader(
      'content-type',
      'application/json',
    );
    request.setBody(OpenApiClientRequestBodyJson(body.toJson()));
    return await sendRequest(
      request,
      {
        '201': (OpenApiClientResponse response) async =>
            _PostResponse201.response201(),
        '400': (OpenApiClientResponse response) async =>
            _PostResponse400.response400(),
      },
    );
  }

  /// Stop test service
  /// delete: /
  ///
  @override
  Future<DeleteResponse> Delete() async {
    final request = OpenApiClientRequest(
      'delete',
      '/',
      [],
    );
    return await sendRequest(
      request,
      {
        '200': (OpenApiClientResponse response) async =>
            _DeleteResponse200.response200()
      },
    );
  }

  /// post: /client/{id}
  ///
  @override
  Future<ClientIdPostResponse> clientIdPost(
    Request body, {
    required int id,
  }) async {
    final request = OpenApiClientRequest(
      'post',
      '/client/{id}',
      [],
    );
    request.addPathParameter(
      'id',
      encodeInt(id),
    );
    request.setHeader(
      'content-type',
      'application/json',
    );
    request.setBody(OpenApiClientRequestBodyJson(body.toJson()));
    return await sendRequest(
      request,
      {
        '200': (OpenApiClientResponse response) async =>
            _ClientIdPostResponse200.response200(
                Response.fromJson(await response.responseBodyJson())),
        '404': (OpenApiClientResponse response) async =>
            _ClientIdPostResponse404.response404(),
      },
    );
  }

  /// Delete client
  /// delete: /client/{id}
  ///
  @override
  Future<ClientIdDeleteResponse> clientIdDelete({required int id}) async {
    final request = OpenApiClientRequest(
      'delete',
      '/client/{id}',
      [],
    );
    request.addPathParameter(
      'id',
      encodeInt(id),
    );
    return await sendRequest(
      request,
      {
        '200': (OpenApiClientResponse response) async =>
            _ClientIdDeleteResponse200.response200(),
        '404': (OpenApiClientResponse response) async =>
            _ClientIdDeleteResponse404.response404(),
      },
    );
  }
}

class SdkTestApiUrlResolve with OpenApiUrlEncodeMixin {
  /// Status resource
  /// get: /
  ///
  OpenApiClientRequest Get() {
    final request = OpenApiClientRequest(
      'get',
      '/',
      [],
    );
    return request;
  }

  /// Create SDK client
  /// post: /
  ///
  OpenApiClientRequest Post() {
    final request = OpenApiClientRequest(
      'post',
      '/',
      [],
    );
    return request;
  }

  /// Stop test service
  /// delete: /
  ///
  OpenApiClientRequest Delete() {
    final request = OpenApiClientRequest(
      'delete',
      '/',
      [],
    );
    return request;
  }

  /// post: /client/{id}
  ///
  OpenApiClientRequest clientIdPost({required int id}) {
    final request = OpenApiClientRequest(
      'post',
      '/client/{id}',
      [],
    );
    request.addPathParameter(
      'id',
      encodeInt(id),
    );
    return request;
  }

  /// Delete client
  /// delete: /client/{id}
  ///
  OpenApiClientRequest clientIdDelete({required int id}) {
    final request = OpenApiClientRequest(
      'delete',
      '/client/{id}',
      [],
    );
    request.addPathParameter(
      'id',
      encodeInt(id),
    );
    return request;
  }
}

class SdkTestApiRouter extends OpenApiServerRouterBase {
  SdkTestApiRouter(this.impl);

  final ApiEndpointProvider<SdkTestApi> impl;

  @override
  void configure() {
    addRoute(
      '/',
      'get',
      (OpenApiRequest request) async {
        return await impl.invoke(
          request,
          (SdkTestApi impl) async => impl.Get(),
        );
      },
      security: [],
    );
    addRoute(
      '/',
      'post',
      (OpenApiRequest request) async {
        return await impl.invoke(
          request,
          (SdkTestApi impl) async =>
              impl.Post(PostSchema.fromJson(await request.readJsonBody())),
        );
      },
      security: [],
    );
    addRoute(
      '/',
      'delete',
      (OpenApiRequest request) async {
        return await impl.invoke(
          request,
          (SdkTestApi impl) async => impl.Delete(),
        );
      },
      security: [],
    );
    addRoute(
      '/client/{id}',
      'post',
      (OpenApiRequest request) async {
        return await impl.invoke(
          request,
          (SdkTestApi impl) async => impl.clientIdPost(
            Request.fromJson(await request.readJsonBody()),
            id: paramRequired(
              name: 'id',
              value: request.pathParameter('id'),
              decode: (value) => paramToInt(value),
            ),
          ),
        );
      },
      security: [],
    );
    addRoute(
      '/client/{id}',
      'delete',
      (OpenApiRequest request) async {
        return await impl.invoke(
          request,
          (SdkTestApi impl) async => impl.clientIdDelete(
              id: paramRequired(
            name: 'id',
            value: request.pathParameter('id'),
            decode: (value) => paramToInt(value),
          )),
        );
      },
      security: [],
    );
  }
}

class SecuritySchemes {}

T _throwStateError<T>(String message) => throw StateError(message);
