import 'dart:async';
import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    as common;
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

import 'protocol.dart';

const int _defaultWaitTimeMillis = 5000;

/// Runs the SDK in the browser for the contract test harness.
///
/// The SDK streams with the HTTP-based SSE client, not with the browser
/// native `EventSource`. The native client cannot send a request body or
/// report an HTTP error.
final class Entity {
  /// `client-event-source-http-errors` and `client-use-post` need the
  /// HTTP-based SSE client. Keep `eventSource: SSEClient.http` in [_create]
  /// while the list declares them.
  static const List<String> capabilities = [
    'client-side',
    'strongly-typed',
    'context-type',
    'context-comparison',
    'service-endpoints',
    'tags',
    'client-independence',
    'inline-context-all',
    'anonymous-redaction',
    'client-per-context-summaries',
    'client-prereq-events',
    'client-prereq-cycle-detection',
    'fdv1-fallback',
    'polling-gzip',
    'client-event-source-http-errors',
    'client-use-post',
  ];

  final Map<int, LDClient> _clients = {};
  int _nextClientId = 0;

  /// Handles one request from the adapter and returns the response. The
  /// response has a `status` that mirrors the HTTP status for the harness.
  Future<Map<String, dynamic>> handle(Map<String, dynamic> request) async {
    try {
      switch (request['op']) {
        case createOp:
          final clientId =
              await _create(request['body'] as Map<String, dynamic>);
          return {'status': 201, 'clientId': clientId};
        case commandOp:
          final client = _clients[request['clientId']];
          if (client == null) {
            return {'status': 404};
          }
          return {
            'status': 200,
            'body':
                await _command(client, request['body'] as Map<String, dynamic>)
          };
        case deleteOp:
          final client = _clients.remove(request['clientId']);
          if (client == null) {
            return {'status': 404};
          }
          await client.close();
          return {'status': 200};
        default:
          return {'status': 400, 'error': 'Unknown op: ${request['op']}'};
      }
    } catch (error, stack) {
      return {'status': 500, 'error': '$error\n$stack'};
    }
  }

  Future<int> _create(Map<String, dynamic> body) async {
    final configuration = body['configuration'] as Map<String, dynamic>? ?? {};
    final clientSide =
        configuration['clientSide'] as Map<String, dynamic>? ?? {};
    final tags = configuration['tags'] as Map<String, dynamic>?;
    final polling = configuration['polling'] as Map<String, dynamic>?;
    final streaming = configuration['streaming'] as Map<String, dynamic>?;
    final events = configuration['events'] as Map<String, dynamic>?;
    final usePost = clientSide['usePost'] as bool? ?? false;
    final mappedDataSystem = _mapDataSystem(
        configuration['dataSystem'] as Map<String, dynamic>?,
        usePost: usePost);
    final startWait = (configuration['startWaitTimeMs'] as num?)?.toInt() ??
        _defaultWaitTimeMillis;

    final config = LDConfig(
      configuration['credential'] as String? ?? '',
      AutoEnvAttributes.disabled,
      applicationInfo: switch (tags) {
        // An empty application ID is invalid, so ApplicationInfo drops it.
        // This keeps a version-only tag configuration working.
        final t?
            when t['applicationId'] != null ||
                t['applicationVersion'] != null =>
          ApplicationInfo(
              applicationId: t['applicationId'] as String? ?? '',
              applicationVersion: t['applicationVersion'] as String?),
        _ => null,
      },
      persistence: PersistenceConfig(maxCachedContexts: 0),
      serviceEndpoints: ServiceEndpoints.custom(
          polling: polling?['baseUri'] as String?,
          streaming: streaming?['baseUri'] as String?,
          events: events?['baseUri'] as String?),
      dataSourceConfig: DataSourceConfig(
          initialConnectionMode: mappedDataSystem?.initialConnectionMode ??
              (streaming != null
                  ? ConnectionMode.streaming
                  : ConnectionMode.polling),
          evaluationReasons: clientSide['evaluationReasons'] as bool?,
          useReport: clientSide['useReport'] as bool?),
      events: EventsConfig(
          eventCapacity: (events?['capacity'] as num?)?.toInt(),
          disabled: events == null,
          diagnosticOptOut: !(events?['enableDiagnostics'] as bool? ?? true)),
      allAttributesPrivate: events?['allAttributesPrivate'] as bool? ?? false,
      globalPrivateAttributes:
          (events?['globalPrivateAttributes'] as List<dynamic>?)
              ?.map((attribute) => attribute as String)
              .toList(),
      dataSystem: mappedDataSystem?.config,
      eventSource: SSEClient.http,
    );

    final context = _flattenedListToContext(_serializedContextToFlattenedList(
        clientSide['initialContext'] as Map<String, dynamic>));
    final client = LDClient(config, context);
    try {
      await client.start().timeout(Duration(milliseconds: startWait));
    } catch (_) {
      // The harness checks the outcome through later commands.
    }

    final clientId = _nextClientId++;
    _clients[clientId] = client;
    return clientId;
  }

  Future<Map<String, dynamic>> _command(
      LDClient client, Map<String, dynamic> body) async {
    switch (body['command']) {
      case 'identifyEvent':
        final context = _flattenedListToContext(
            _serializedContextToFlattenedList((body['identifyEvent']
                as Map<String, dynamic>)['context'] as Map<String, dynamic>));
        await client.identify(context);
        return {};
      case 'evaluate':
        return _evaluate(client, body['evaluate'] as Map<String, dynamic>);
      case 'evaluateAll':
        return {
          'state': client.allFlags().map((key, value) =>
              MapEntry(key, common.LDValueSerialization.toJson(value)))
        };
      case 'customEvent':
        final event = body['customEvent'] as Map<String, dynamic>;
        client.track(event['eventKey'] as String,
            data: common.LDValueSerialization.fromJson(event['data']),
            metricValue: (event['metricValue'] as num?)?.toDouble());
        return {};
      case 'flushEvents':
        client.flush();
        return {};
      case 'contextBuild':
        final context = _contextFromSingleOrMulti(
            body['contextBuild'] as Map<String, dynamic>);
        return {
          'output': jsonEncode(
              common.LDContextSerialization.toJson(context, isEvent: false))
        };
      case 'contextConvert':
        return _contextConvert((body['contextConvert']
            as Map<String, dynamic>)['input'] as String);
      case 'contextComparison':
        final comparison = body['contextComparison'] as Map<String, dynamic>;
        return {
          'equals': _buildContextForComparison(
                  comparison['context1'] as Map<String, dynamic>) ==
              _buildContextForComparison(
                  comparison['context2'] as Map<String, dynamic>)
        };
      default:
        throw UnimplementedError('Unknown command: ${body['command']}');
    }
  }

  Map<String, dynamic> _evaluate(
      LDClient client, Map<String, dynamic> request) {
    final flagKey = request['flagKey'] as String;
    final defaultValue = request['defaultValue'];
    final valueType = request['valueType'] as String?;

    if (request['detail'] as bool? ?? false) {
      final LDEvaluationDetail<LDValue> detail;
      switch (valueType) {
        case 'bool':
          final result =
              client.boolVariationDetail(flagKey, defaultValue as bool);
          detail = LDEvaluationDetail(LDValue.ofBool(result.value),
              result.variationIndex, result.reason);
        case 'int':
          final result =
              client.intVariationDetail(flagKey, (defaultValue as num).toInt());
          detail = LDEvaluationDetail(LDValue.ofNum(result.value),
              result.variationIndex, result.reason);
        case 'double':
          final result = client.doubleVariationDetail(
              flagKey, (defaultValue as num).toDouble());
          detail = LDEvaluationDetail(LDValue.ofNum(result.value),
              result.variationIndex, result.reason);
        case 'string':
          final result =
              client.stringVariationDetail(flagKey, defaultValue as String);
          detail = LDEvaluationDetail(LDValue.ofString(result.value),
              result.variationIndex, result.reason);
        default:
          detail = client.jsonVariationDetail(
              flagKey, common.LDValueSerialization.fromJson(defaultValue));
      }
      return common.LDEvaluationDetailSerialization.toJson(detail);
    }

    final LDValue value;
    switch (valueType) {
      case 'bool':
        value =
            LDValue.ofBool(client.boolVariation(flagKey, defaultValue as bool));
      case 'int':
        value = LDValue.ofNum(
            client.intVariation(flagKey, (defaultValue as num).toInt()));
      case 'double':
        value = LDValue.ofNum(
            client.doubleVariation(flagKey, (defaultValue as num).toDouble()));
      case 'string':
        value = LDValue.ofString(
            client.stringVariation(flagKey, defaultValue as String));
      default:
        value = client.jsonVariation(
            flagKey, common.LDValueSerialization.fromJson(defaultValue));
    }
    // A null result is omitted. An absent key reads the same as null.
    return {
      if (common.LDValueSerialization.toJson(value) case final Object json)
        'value': json,
    };
  }

  Map<String, dynamic> _contextConvert(String input) {
    try {
      final decoded = jsonDecode(input) as Map<String, dynamic>;
      final context =
          _flattenedListToContext(_serializedContextToFlattenedList(decoded));
      if (context.valid) {
        return {
          'output': jsonEncode(
              common.LDContextSerialization.toJson(context, isEvent: false))
        };
      }
      return {'error': 'Context was invalid.'};
    } catch (error) {
      return {'error': error.toString()};
    }
  }

  /// Translates the harness `dataSystem` configuration block into the
  /// SDK's [DataSystemConfig] and an initial connection mode.
  ///
  /// [usePost] is the harness `clientSide.usePost` flag. Under FDv2 it
  /// selects POST requests with the context in the body.
  ({DataSystemConfig config, ConnectionMode initialConnectionMode})?
      _mapDataSystem(Map<String, dynamic>? raw, {required bool usePost}) {
    if (raw == null) {
      return null;
    }

    Fdv1FallbackConfig? parseFdv1Fallback() {
      if (raw['fdv1Fallback'] case final Map<String, dynamic> fallback) {
        return Fdv1FallbackConfig(
          pollInterval: fallback['pollIntervalMs'] != null
              ? Duration(
                  milliseconds: (fallback['pollIntervalMs'] as num).toInt())
              : null,
          endpoints: fallback['baseUri'] != null
              ? EndpointConfig(
                  pollingBaseUri: Uri.parse(fallback['baseUri'] as String))
              : null,
        );
      }
      return null;
    }

    final fdv1Fallback = parseFdv1Fallback();

    ModeDefinition translateMode(Map<String, dynamic> modeJson) {
      final initializers = <InitializerEntry>[];
      for (final entry in (modeJson['initializers'] as List<dynamic>? ?? [])) {
        final initializer = entry as Map<String, dynamic>;
        if (initializer['polling'] case final Map<String, dynamic> polling) {
          initializers.add(PollingInitializer(
              endpoints: EndpointConfig(
                  pollingBaseUri: polling['baseUri'] != null
                      ? Uri.parse(polling['baseUri'] as String)
                      : null)));
        }
      }

      final synchronizers = <SynchronizerEntry>[];
      for (final entry in (modeJson['synchronizers'] as List<dynamic>? ?? [])) {
        final synchronizer = entry as Map<String, dynamic>;
        if (synchronizer['streaming']
            case final Map<String, dynamic> streaming) {
          synchronizers.add(StreamingSynchronizer(
              initialReconnectDelay: streaming['initialRetryDelayMs'] != null
                  ? Duration(
                      milliseconds:
                          (streaming['initialRetryDelayMs'] as num).toInt())
                  : null,
              endpoints: EndpointConfig(
                  streamingBaseUri: streaming['baseUri'] != null
                      ? Uri.parse(streaming['baseUri'] as String)
                      : null)));
        } else if (synchronizer['polling']
            case final Map<String, dynamic> polling) {
          synchronizers.add(PollingSynchronizer(
              pollInterval: polling['pollIntervalMs'] != null
                  ? Duration(
                      milliseconds: (polling['pollIntervalMs'] as num).toInt())
                  : null,
              endpoints: EndpointConfig(
                  pollingBaseUri: polling['baseUri'] != null
                      ? Uri.parse(polling['baseUri'] as String)
                      : null)));
        }
      }

      return ModeDefinition(
          initializers: initializers,
          synchronizers: synchronizers,
          fdv1Fallback: fdv1Fallback);
    }

    ConnectionMode parseInitialMode(String? name) {
      return switch (name) {
        'polling' => ConnectionMode.polling,
        'offline' => ConnectionMode.offline,
        _ => ConnectionMode.streaming,
      };
    }

    ConnectionModeId? builtInModeId(String name) {
      return switch (name) {
        'streaming' => ConnectionModeId.streaming,
        'polling' => ConnectionModeId.polling,
        'background' => ConnectionModeId.background,
        'offline' => ConnectionModeId.offline,
        _ => null,
      };
    }

    if (raw['connectionModeConfig'] case final Map<String, dynamic> connMode) {
      final overrides = <ConnectionModeId, ModeDefinition>{};
      if (connMode['customConnectionModes']
          case final Map<String, dynamic> modes) {
        for (final entry in modes.entries) {
          if (builtInModeId(entry.key) case final id?) {
            overrides[id] = translateMode(entry.value as Map<String, dynamic>);
          }
        }
      }
      final initialModeName = connMode['initialConnectionMode'] as String?;
      return (
        config: DataSystemConfig(
          connectionModes: overrides,
          initialConnectionMode:
              initialModeName == null ? null : builtInModeId(initialModeName),
          usePost: usePost,
        ),
        initialConnectionMode: parseInitialMode(initialModeName),
      );
    }

    if (raw['initializers'] != null || raw['synchronizers'] != null) {
      return (
        config: DataSystemConfig(
            connectionModes: {ConnectionModeId.streaming: translateMode(raw)},
            usePost: usePost),
        initialConnectionMode: ConnectionMode.streaming,
      );
    }

    return (
      config: DataSystemConfig(usePost: usePost),
      initialConnectionMode: ConnectionMode.streaming,
    );
  }

  LDContext _contextFromSingleOrMulti(Map<String, dynamic> input) {
    if (input['single'] case final Map<String, dynamic> single) {
      return _flattenedListToContext([_buildContextToFlattenedMap(single)]);
    }
    if (input['multi'] case final List<dynamic> multi) {
      return _flattenedListToContext([
        for (final single in multi)
          _buildContextToFlattenedMap(single as Map<String, dynamic>)
      ]);
    }
    throw UnsupportedError(
        'Expected a single or multi context, but neither were provided.');
  }

  LDContext _buildContextForComparison(Map<String, dynamic> input) {
    final builder = LDContextBuilder();
    if (input['single'] case final Map<String, dynamic> single) {
      _buildSingleAttributes(
          builder.kind(single['kind'] as String, single['key'] as String?),
          single);
      return builder.build();
    }
    if (input['multi'] case final List<dynamic> multi) {
      for (final entry in multi) {
        final single = entry as Map<String, dynamic>;
        _buildSingleAttributes(
            builder.kind(single['kind'] as String, single['key'] as String?),
            single);
      }
      return builder.build();
    }
    throw UnsupportedError(
        'Expected a single or multi context, but neither were provided.');
  }

  void _buildSingleAttributes(LDAttributesBuilder singleAttributesBuilder,
      Map<String, dynamic> single) {
    final attributes = single['attributes'] as List<dynamic>?;
    final privateAttributes = single['privateAttributes'] as List<dynamic>?;
    if (attributes != null) {
      for (final item in attributes) {
        singleAttributesBuilder.setValue(
            item['name'], LDValue.ofDynamic(item['value']));
      }
    }
    if (privateAttributes != null) {
      for (final item in privateAttributes) {
        // A literal is not a valid reference as written, so it is escaped
        // through the reference type first.
        if (item['literal']) {
          singleAttributesBuilder.addPrivateAttributes([
            AttributeReference.fromComponents(
                    common.AttributeReference.fromLiteral(item['value'])
                        .components)
                .redactionName
          ]);
        } else {
          singleAttributesBuilder.addPrivateAttributes([item['value']]);
        }
      }
    }
  }

  /// Creates a map for one context from the `contextBuild` command structure.
  Map<String, dynamic> _buildContextToFlattenedMap(Map<String, dynamic> input) {
    final result = <String, dynamic>{
      'kind': input['kind'],
      'key': input['key'],
      'name': input['name'],
      'anonymous': input['anonymous'],
    };
    if (input['private'] != null) {
      result['_meta'] = {'privateAttributes': input['private']};
    }
    result.addAll(input['custom'] as Map<String, dynamic>? ?? {});
    return result;
  }

  /// Creates a flat list of single context maps from serialized JSON.
  List<Map<String, dynamic>> _serializedContextToFlattenedList(
      Map<String, dynamic> json) {
    final result = <Map<String, dynamic>>[];
    if (json['kind'] == 'multi') {
      for (final entry in json.entries) {
        if (entry.key == 'kind') {
          continue;
        }
        final single =
            Map<String, dynamic>.of(entry.value as Map<String, dynamic>);
        single['kind'] = entry.key;
        result.add(single);
      }
    } else {
      result.add(Map<String, dynamic>.of(json));
    }
    return result;
  }

  LDContext _flattenedListToContext(List<Map<String, dynamic>> flattened) {
    final builder = LDContextBuilder();
    for (final attributes in flattened) {
      // Explicit casts, because a release web build omits the implicit ones
      // and would accept a key that is not a string.
      final attrsBuilder = builder.kind(attributes['kind'] as String? ?? 'user',
          attributes['key'] as String?);
      for (final a in attributes.entries) {
        if (a.key == 'kind' || a.key == 'key') {
          continue;
        }
        attrsBuilder.setValue(
            a.key, common.LDValueSerialization.fromJson(a.value));
      }
      final meta = attributes['_meta'] as Map<String, dynamic>? ?? {};
      final privateAttributes =
          ((meta['privateAttributes'] ?? []) as List<dynamic>)
              .map((e) => e as String)
              .toList();
      attrsBuilder.addPrivateAttributes(privateAttributes);
    }
    return builder.build();
  }
}
