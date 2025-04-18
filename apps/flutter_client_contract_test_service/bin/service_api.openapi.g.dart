// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_api.openapi.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestIdentifyEventContext _$RequestIdentifyEventContextFromJson(
        Map<String, dynamic> json) =>
    RequestIdentifyEventContext();

Map<String, dynamic> _$RequestIdentifyEventContextToJson(
        RequestIdentifyEventContext instance) =>
    <String, dynamic>{};

RequestIdentifyEvent _$RequestIdentifyEventFromJson(
        Map<String, dynamic> json) =>
    RequestIdentifyEvent(
      context: json['context'] == null
          ? null
          : RequestIdentifyEventContext.fromJson(
              json['context'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RequestIdentifyEventToJson(
        RequestIdentifyEvent instance) =>
    <String, dynamic>{
      if (instance.context case final value?) 'context': value,
    };

RequestEvaluateContext _$RequestEvaluateContextFromJson(
        Map<String, dynamic> json) =>
    RequestEvaluateContext();

Map<String, dynamic> _$RequestEvaluateContextToJson(
        RequestEvaluateContext instance) =>
    <String, dynamic>{};

RequestEvaluateUser _$RequestEvaluateUserFromJson(Map<String, dynamic> json) =>
    RequestEvaluateUser();

Map<String, dynamic> _$RequestEvaluateUserToJson(
        RequestEvaluateUser instance) =>
    <String, dynamic>{};

RequestEvaluate _$RequestEvaluateFromJson(Map<String, dynamic> json) =>
    RequestEvaluate(
      flagKey: json['flagKey'] as String?,
      context: json['context'] == null
          ? null
          : RequestEvaluateContext.fromJson(
              json['context'] as Map<String, dynamic>),
      user: json['user'] == null
          ? null
          : RequestEvaluateUser.fromJson(json['user'] as Map<String, dynamic>),
      valueType: json['valueType'] as String?,
      detail: json['detail'] as bool?,
    );

Map<String, dynamic> _$RequestEvaluateToJson(RequestEvaluate instance) =>
    <String, dynamic>{
      if (instance.flagKey case final value?) 'flagKey': value,
      if (instance.context case final value?) 'context': value,
      if (instance.user case final value?) 'user': value,
      if (instance.valueType case final value?) 'valueType': value,
      if (instance.detail case final value?) 'detail': value,
    };

RequestEvaluateAllContext _$RequestEvaluateAllContextFromJson(
        Map<String, dynamic> json) =>
    RequestEvaluateAllContext();

Map<String, dynamic> _$RequestEvaluateAllContextToJson(
        RequestEvaluateAllContext instance) =>
    <String, dynamic>{};

RequestEvaluateAllUser _$RequestEvaluateAllUserFromJson(
        Map<String, dynamic> json) =>
    RequestEvaluateAllUser();

Map<String, dynamic> _$RequestEvaluateAllUserToJson(
        RequestEvaluateAllUser instance) =>
    <String, dynamic>{};

RequestEvaluateAll _$RequestEvaluateAllFromJson(Map<String, dynamic> json) =>
    RequestEvaluateAll(
      context: json['context'] == null
          ? null
          : RequestEvaluateAllContext.fromJson(
              json['context'] as Map<String, dynamic>),
      user: json['user'] == null
          ? null
          : RequestEvaluateAllUser.fromJson(
              json['user'] as Map<String, dynamic>),
      withReasons: json['withReasons'] as bool?,
      clientSideOnly: json['clientSideOnly'] as bool?,
      detailsOnlyForTrackedFlags: json['detailsOnlyForTrackedFlags'] as bool?,
    );

Map<String, dynamic> _$RequestEvaluateAllToJson(RequestEvaluateAll instance) =>
    <String, dynamic>{
      if (instance.context case final value?) 'context': value,
      if (instance.user case final value?) 'user': value,
      if (instance.withReasons case final value?) 'withReasons': value,
      if (instance.clientSideOnly case final value?) 'clientSideOnly': value,
      if (instance.detailsOnlyForTrackedFlags case final value?)
        'detailsOnlyForTrackedFlags': value,
    };

RequestCustomEvent _$RequestCustomEventFromJson(Map<String, dynamic> json) =>
    RequestCustomEvent(
      eventKey: json['eventKey'] as String?,
      omitNullData: json['omitNullData'] as bool?,
      metricValue: json['metricValue'] as num?,
    );

Map<String, dynamic> _$RequestCustomEventToJson(RequestCustomEvent instance) =>
    <String, dynamic>{
      if (instance.eventKey case final value?) 'eventKey': value,
      if (instance.omitNullData case final value?) 'omitNullData': value,
      if (instance.metricValue case final value?) 'metricValue': value,
    };

BuildContext _$BuildContextFromJson(Map<String, dynamic> json) =>
    BuildContext();

Map<String, dynamic> _$BuildContextToJson(BuildContext instance) =>
    <String, dynamic>{};

SingleOrMultiBuildContext _$SingleOrMultiBuildContextFromJson(
        Map<String, dynamic> json) =>
    SingleOrMultiBuildContext(
      single: json['single'] == null
          ? null
          : BuildContext.fromJson(json['single'] as Map<String, dynamic>),
      multi: (json['multi'] as List<dynamic>?)
          ?.map((e) => BuildContext.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SingleOrMultiBuildContextToJson(
        SingleOrMultiBuildContext instance) =>
    <String, dynamic>{
      if (instance.single case final value?) 'single': value,
      if (instance.multi case final value?) 'multi': value,
    };

RequestContextConvert _$RequestContextConvertFromJson(
        Map<String, dynamic> json) =>
    RequestContextConvert(
      input: json['input'] as String?,
    );

Map<String, dynamic> _$RequestContextConvertToJson(
        RequestContextConvert instance) =>
    <String, dynamic>{
      if (instance.input case final value?) 'input': value,
    };

RequestContextComparison _$RequestContextComparisonFromJson(
        Map<String, dynamic> json) =>
    RequestContextComparison(
      context1: json['context1'] == null
          ? null
          : SingleOrMultiBuildContext.fromJson(
              json['context1'] as Map<String, dynamic>),
      context2: json['context2'] == null
          ? null
          : SingleOrMultiBuildContext.fromJson(
              json['context2'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RequestContextComparisonToJson(
        RequestContextComparison instance) =>
    <String, dynamic>{
      if (instance.context1 case final value?) 'context1': value,
      if (instance.context2 case final value?) 'context2': value,
    };

Request _$RequestFromJson(Map<String, dynamic> json) => Request(
      command: json['command'] as String?,
      identifyEvent: json['identifyEvent'] == null
          ? null
          : RequestIdentifyEvent.fromJson(
              json['identifyEvent'] as Map<String, dynamic>),
      evaluate: json['evaluate'] == null
          ? null
          : RequestEvaluate.fromJson(json['evaluate'] as Map<String, dynamic>),
      evaluateAll: json['evaluateAll'] == null
          ? null
          : RequestEvaluateAll.fromJson(
              json['evaluateAll'] as Map<String, dynamic>),
      customEvent: json['customEvent'] == null
          ? null
          : RequestCustomEvent.fromJson(
              json['customEvent'] as Map<String, dynamic>),
      contextBuild: json['contextBuild'] == null
          ? null
          : SingleOrMultiBuildContext.fromJson(
              json['contextBuild'] as Map<String, dynamic>),
      contextConvert: json['contextConvert'] == null
          ? null
          : RequestContextConvert.fromJson(
              json['contextConvert'] as Map<String, dynamic>),
      contextComparison: json['contextComparison'] == null
          ? null
          : RequestContextComparison.fromJson(
              json['contextComparison'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RequestToJson(Request instance) => <String, dynamic>{
      if (instance.command case final value?) 'command': value,
      if (instance.identifyEvent case final value?) 'identifyEvent': value,
      if (instance.evaluate case final value?) 'evaluate': value,
      if (instance.evaluateAll case final value?) 'evaluateAll': value,
      if (instance.customEvent case final value?) 'customEvent': value,
      if (instance.contextBuild case final value?) 'contextBuild': value,
      if (instance.contextConvert case final value?) 'contextConvert': value,
      if (instance.contextComparison case final value?)
        'contextComparison': value,
    };

Response _$ResponseFromJson(Map<String, dynamic> json) => Response();

Map<String, dynamic> _$ResponseToJson(Response instance) => <String, dynamic>{};

GetResponseBody200 _$GetResponseBody200FromJson(Map<String, dynamic> json) =>
    GetResponseBody200(
      name: json['name'] as String?,
      clientVersion: json['clientVersion'] as String?,
      capabilities: (json['capabilities'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$GetResponseBody200ToJson(GetResponseBody200 instance) =>
    <String, dynamic>{
      if (instance.name case final value?) 'name': value,
      if (instance.clientVersion case final value?) 'clientVersion': value,
      if (instance.capabilities case final value?) 'capabilities': value,
    };

PostSchemaConfigurationServiceEndpoints
    _$PostSchemaConfigurationServiceEndpointsFromJson(
            Map<String, dynamic> json) =>
        PostSchemaConfigurationServiceEndpoints(
          streaming: json['streaming'] as String?,
          polling: json['polling'] as String?,
          events: json['events'] as String?,
        );

Map<String, dynamic> _$PostSchemaConfigurationServiceEndpointsToJson(
        PostSchemaConfigurationServiceEndpoints instance) =>
    <String, dynamic>{
      if (instance.streaming case final value?) 'streaming': value,
      if (instance.polling case final value?) 'polling': value,
      if (instance.events case final value?) 'events': value,
    };

PostSchemaConfigurationStreaming _$PostSchemaConfigurationStreamingFromJson(
        Map<String, dynamic> json) =>
    PostSchemaConfigurationStreaming(
      baseUri: json['baseUri'] as String?,
      initialRetryDelayMs: json['initialRetryDelayMs'] as num?,
      filter: json['filter'] as String?,
    );

Map<String, dynamic> _$PostSchemaConfigurationStreamingToJson(
        PostSchemaConfigurationStreaming instance) =>
    <String, dynamic>{
      if (instance.baseUri case final value?) 'baseUri': value,
      if (instance.initialRetryDelayMs case final value?)
        'initialRetryDelayMs': value,
      if (instance.filter case final value?) 'filter': value,
    };

PostSchemaConfigurationPolling _$PostSchemaConfigurationPollingFromJson(
        Map<String, dynamic> json) =>
    PostSchemaConfigurationPolling(
      baseUri: json['baseUri'] as String?,
      pollIntervalMs: json['pollIntervalMs'] as num?,
      filter: json['filter'] as String?,
    );

Map<String, dynamic> _$PostSchemaConfigurationPollingToJson(
        PostSchemaConfigurationPolling instance) =>
    <String, dynamic>{
      if (instance.baseUri case final value?) 'baseUri': value,
      if (instance.pollIntervalMs case final value?) 'pollIntervalMs': value,
      if (instance.filter case final value?) 'filter': value,
    };

PostSchemaConfigurationEvents _$PostSchemaConfigurationEventsFromJson(
        Map<String, dynamic> json) =>
    PostSchemaConfigurationEvents(
      baseUri: json['baseUri'] as String?,
      capacity: json['capacity'] as num?,
      enableDiagnostics: json['enableDiagnostics'] as bool?,
      allAttributesPrivate: json['allAttributesPrivate'] as bool?,
      globalPrivateAttributes:
          (json['globalPrivateAttributes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      flushIntervalMs: json['flushIntervalMs'] as num?,
    );

Map<String, dynamic> _$PostSchemaConfigurationEventsToJson(
        PostSchemaConfigurationEvents instance) =>
    <String, dynamic>{
      if (instance.baseUri case final value?) 'baseUri': value,
      if (instance.capacity case final value?) 'capacity': value,
      if (instance.enableDiagnostics case final value?)
        'enableDiagnostics': value,
      if (instance.allAttributesPrivate case final value?)
        'allAttributesPrivate': value,
      if (instance.globalPrivateAttributes case final value?)
        'globalPrivateAttributes': value,
      if (instance.flushIntervalMs case final value?) 'flushIntervalMs': value,
    };

PostSchemaConfigurationBigSegments _$PostSchemaConfigurationBigSegmentsFromJson(
        Map<String, dynamic> json) =>
    PostSchemaConfigurationBigSegments(
      callbackUri: json['callbackUri'] as String?,
      userCacheSize: json['userCacheSize'] as num?,
      userCacheTimeMs: json['userCacheTimeMs'] as num?,
      statusPollIntervalMS: json['statusPollIntervalMS'] as num?,
      staleAfterMs: json['staleAfterMs'] as num?,
    );

Map<String, dynamic> _$PostSchemaConfigurationBigSegmentsToJson(
        PostSchemaConfigurationBigSegments instance) =>
    <String, dynamic>{
      if (instance.callbackUri case final value?) 'callbackUri': value,
      if (instance.userCacheSize case final value?) 'userCacheSize': value,
      if (instance.userCacheTimeMs case final value?) 'userCacheTimeMs': value,
      if (instance.statusPollIntervalMS case final value?)
        'statusPollIntervalMS': value,
      if (instance.staleAfterMs case final value?) 'staleAfterMs': value,
    };

PostSchemaConfigurationTags _$PostSchemaConfigurationTagsFromJson(
        Map<String, dynamic> json) =>
    PostSchemaConfigurationTags(
      applicationId: json['applicationId'] as String?,
      applicationVersion: json['applicationVersion'] as String?,
    );

Map<String, dynamic> _$PostSchemaConfigurationTagsToJson(
        PostSchemaConfigurationTags instance) =>
    <String, dynamic>{
      if (instance.applicationId case final value?) 'applicationId': value,
      if (instance.applicationVersion case final value?)
        'applicationVersion': value,
    };

PostSchemaConfigurationClientSideInitialContext
    _$PostSchemaConfigurationClientSideInitialContextFromJson(
            Map<String, dynamic> json) =>
        PostSchemaConfigurationClientSideInitialContext();

Map<String, dynamic> _$PostSchemaConfigurationClientSideInitialContextToJson(
        PostSchemaConfigurationClientSideInitialContext instance) =>
    <String, dynamic>{};

PostSchemaConfigurationClientSideInitialUser
    _$PostSchemaConfigurationClientSideInitialUserFromJson(
            Map<String, dynamic> json) =>
        PostSchemaConfigurationClientSideInitialUser();

Map<String, dynamic> _$PostSchemaConfigurationClientSideInitialUserToJson(
        PostSchemaConfigurationClientSideInitialUser instance) =>
    <String, dynamic>{};

PostSchemaConfigurationClientSide _$PostSchemaConfigurationClientSideFromJson(
        Map<String, dynamic> json) =>
    PostSchemaConfigurationClientSide(
      initialContext: json['initialContext'] == null
          ? null
          : PostSchemaConfigurationClientSideInitialContext.fromJson(
              json['initialContext'] as Map<String, dynamic>),
      initialUser: json['initialUser'] == null
          ? null
          : PostSchemaConfigurationClientSideInitialUser.fromJson(
              json['initialUser'] as Map<String, dynamic>),
      evaluationReasons: json['evaluationReasons'] as bool?,
      useReport: json['useReport'] as bool?,
    );

Map<String, dynamic> _$PostSchemaConfigurationClientSideToJson(
        PostSchemaConfigurationClientSide instance) =>
    <String, dynamic>{
      if (instance.initialContext case final value?) 'initialContext': value,
      if (instance.initialUser case final value?) 'initialUser': value,
      if (instance.evaluationReasons case final value?)
        'evaluationReasons': value,
      if (instance.useReport case final value?) 'useReport': value,
    };

PostSchemaConfiguration _$PostSchemaConfigurationFromJson(
        Map<String, dynamic> json) =>
    PostSchemaConfiguration(
      credential: json['credential'] as String?,
      startWaitTimeMs: json['startWaitTimeMs'] as num?,
      initCanFail: json['initCanFail'] as bool?,
      serviceEndpoints: json['serviceEndpoints'] == null
          ? null
          : PostSchemaConfigurationServiceEndpoints.fromJson(
              json['serviceEndpoints'] as Map<String, dynamic>),
      streaming: json['streaming'] == null
          ? null
          : PostSchemaConfigurationStreaming.fromJson(
              json['streaming'] as Map<String, dynamic>),
      polling: json['polling'] == null
          ? null
          : PostSchemaConfigurationPolling.fromJson(
              json['polling'] as Map<String, dynamic>),
      events: json['events'] == null
          ? null
          : PostSchemaConfigurationEvents.fromJson(
              json['events'] as Map<String, dynamic>),
      bigSegments: json['bigSegments'] == null
          ? null
          : PostSchemaConfigurationBigSegments.fromJson(
              json['bigSegments'] as Map<String, dynamic>),
      tags: json['tags'] == null
          ? null
          : PostSchemaConfigurationTags.fromJson(
              json['tags'] as Map<String, dynamic>),
      clientSide: json['clientSide'] == null
          ? null
          : PostSchemaConfigurationClientSide.fromJson(
              json['clientSide'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PostSchemaConfigurationToJson(
        PostSchemaConfiguration instance) =>
    <String, dynamic>{
      if (instance.credential case final value?) 'credential': value,
      if (instance.startWaitTimeMs case final value?) 'startWaitTimeMs': value,
      if (instance.initCanFail case final value?) 'initCanFail': value,
      if (instance.serviceEndpoints case final value?)
        'serviceEndpoints': value,
      if (instance.streaming case final value?) 'streaming': value,
      if (instance.polling case final value?) 'polling': value,
      if (instance.events case final value?) 'events': value,
      if (instance.bigSegments case final value?) 'bigSegments': value,
      if (instance.tags case final value?) 'tags': value,
      if (instance.clientSide case final value?) 'clientSide': value,
    };

PostSchema _$PostSchemaFromJson(Map<String, dynamic> json) => PostSchema(
      tag: json['tag'] as String?,
      configuration: json['configuration'] == null
          ? null
          : PostSchemaConfiguration.fromJson(
              json['configuration'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PostSchemaToJson(PostSchema instance) =>
    <String, dynamic>{
      if (instance.tag case final value?) 'tag': value,
      if (instance.configuration case final value?) 'configuration': value,
    };
