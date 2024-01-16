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
    RequestIdentifyEvent instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('context', instance.context);
  return val;
}

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

Map<String, dynamic> _$RequestEvaluateToJson(RequestEvaluate instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('flagKey', instance.flagKey);
  writeNotNull('context', instance.context);
  writeNotNull('user', instance.user);
  writeNotNull('valueType', instance.valueType);
  writeNotNull('detail', instance.detail);
  return val;
}

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

Map<String, dynamic> _$RequestEvaluateAllToJson(RequestEvaluateAll instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('context', instance.context);
  writeNotNull('user', instance.user);
  writeNotNull('withReasons', instance.withReasons);
  writeNotNull('clientSideOnly', instance.clientSideOnly);
  writeNotNull(
      'detailsOnlyForTrackedFlags', instance.detailsOnlyForTrackedFlags);
  return val;
}

RequestCustomEvent _$RequestCustomEventFromJson(Map<String, dynamic> json) =>
    RequestCustomEvent(
      eventKey: json['eventKey'] as String?,
      omitNullData: json['omitNullData'] as bool?,
      metricValue: json['metricValue'] as num?,
    );

Map<String, dynamic> _$RequestCustomEventToJson(RequestCustomEvent instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('eventKey', instance.eventKey);
  writeNotNull('omitNullData', instance.omitNullData);
  writeNotNull('metricValue', instance.metricValue);
  return val;
}

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
    );

Map<String, dynamic> _$RequestToJson(Request instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('command', instance.command);
  writeNotNull('identifyEvent', instance.identifyEvent);
  writeNotNull('evaluate', instance.evaluate);
  writeNotNull('evaluateAll', instance.evaluateAll);
  writeNotNull('customEvent', instance.customEvent);
  return val;
}

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

Map<String, dynamic> _$GetResponseBody200ToJson(GetResponseBody200 instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('clientVersion', instance.clientVersion);
  writeNotNull('capabilities', instance.capabilities);
  return val;
}

PostSchemaConfigurationServiceEndpoints
    _$PostSchemaConfigurationServiceEndpointsFromJson(
            Map<String, dynamic> json) =>
        PostSchemaConfigurationServiceEndpoints(
          streaming: json['streaming'] as String?,
          polling: json['polling'] as String?,
          events: json['events'] as String?,
        );

Map<String, dynamic> _$PostSchemaConfigurationServiceEndpointsToJson(
    PostSchemaConfigurationServiceEndpoints instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('streaming', instance.streaming);
  writeNotNull('polling', instance.polling);
  writeNotNull('events', instance.events);
  return val;
}

PostSchemaConfigurationStreaming _$PostSchemaConfigurationStreamingFromJson(
        Map<String, dynamic> json) =>
    PostSchemaConfigurationStreaming(
      baseUri: json['baseUri'] as String?,
      initialRetryDelayMs: json['initialRetryDelayMs'] as num?,
      filter: json['filter'] as String?,
    );

Map<String, dynamic> _$PostSchemaConfigurationStreamingToJson(
    PostSchemaConfigurationStreaming instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('baseUri', instance.baseUri);
  writeNotNull('initialRetryDelayMs', instance.initialRetryDelayMs);
  writeNotNull('filter', instance.filter);
  return val;
}

PostSchemaConfigurationPolling _$PostSchemaConfigurationPollingFromJson(
        Map<String, dynamic> json) =>
    PostSchemaConfigurationPolling(
      baseUri: json['baseUri'] as String?,
      pollIntervalMs: json['pollIntervalMs'] as num?,
      filter: json['filter'] as String?,
    );

Map<String, dynamic> _$PostSchemaConfigurationPollingToJson(
    PostSchemaConfigurationPolling instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('baseUri', instance.baseUri);
  writeNotNull('pollIntervalMs', instance.pollIntervalMs);
  writeNotNull('filter', instance.filter);
  return val;
}

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
    PostSchemaConfigurationEvents instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('baseUri', instance.baseUri);
  writeNotNull('capacity', instance.capacity);
  writeNotNull('enableDiagnostics', instance.enableDiagnostics);
  writeNotNull('allAttributesPrivate', instance.allAttributesPrivate);
  writeNotNull('globalPrivateAttributes', instance.globalPrivateAttributes);
  writeNotNull('flushIntervalMs', instance.flushIntervalMs);
  return val;
}

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
    PostSchemaConfigurationBigSegments instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('callbackUri', instance.callbackUri);
  writeNotNull('userCacheSize', instance.userCacheSize);
  writeNotNull('userCacheTimeMs', instance.userCacheTimeMs);
  writeNotNull('statusPollIntervalMS', instance.statusPollIntervalMS);
  writeNotNull('staleAfterMs', instance.staleAfterMs);
  return val;
}

PostSchemaConfigurationTags _$PostSchemaConfigurationTagsFromJson(
        Map<String, dynamic> json) =>
    PostSchemaConfigurationTags(
      applicationId: json['applicationId'] as String?,
      applicationVersion: json['applicationVersion'] as String?,
    );

Map<String, dynamic> _$PostSchemaConfigurationTagsToJson(
    PostSchemaConfigurationTags instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('applicationId', instance.applicationId);
  writeNotNull('applicationVersion', instance.applicationVersion);
  return val;
}

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
    PostSchemaConfigurationClientSide instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('initialContext', instance.initialContext);
  writeNotNull('initialUser', instance.initialUser);
  writeNotNull('evaluationReasons', instance.evaluationReasons);
  writeNotNull('useReport', instance.useReport);
  return val;
}

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
    PostSchemaConfiguration instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('credential', instance.credential);
  writeNotNull('startWaitTimeMs', instance.startWaitTimeMs);
  writeNotNull('initCanFail', instance.initCanFail);
  writeNotNull('serviceEndpoints', instance.serviceEndpoints);
  writeNotNull('streaming', instance.streaming);
  writeNotNull('polling', instance.polling);
  writeNotNull('events', instance.events);
  writeNotNull('bigSegments', instance.bigSegments);
  writeNotNull('tags', instance.tags);
  writeNotNull('clientSide', instance.clientSide);
  return val;
}

PostSchema _$PostSchemaFromJson(Map<String, dynamic> json) => PostSchema(
      tag: json['tag'] as String?,
      configuration: json['configuration'] == null
          ? null
          : PostSchemaConfiguration.fromJson(
              json['configuration'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PostSchemaToJson(PostSchema instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('tag', instance.tag);
  writeNotNull('configuration', instance.configuration);
  return val;
}
