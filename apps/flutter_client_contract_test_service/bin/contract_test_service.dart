import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' as widgets;
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    as common;
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';
import 'package:openapi_base/openapi_base.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_api.openapi.dart';

class TestApiImpl extends SdkTestApi {
  static const capabilities = [
    "client-side",
    "mobile",
    "strongly-typed",
    "context-type",
    "context-comparison",
    "service-endpoints",
    "tags",
    "inline-context",
    "anonymous-redaction"
  ];

  static const clientUrlPrefix = "/client/";
  static const defaultWaitTimeMillis = 5000;

  final Map<int, LDClient> clientMap = {};
  var nextIdToGive = 0;

  @override
  // ignore: non_constant_identifier_names
  Future<GetResponse> Get() async {
    return GetResponse.response200(GetResponseBody200(
        name: 'flutter-client-sdk', capabilities: capabilities));
  }

  @override
  // ignore: non_constant_identifier_names
  Future<PostResponse> Post(PostSchema body) async {
    final startWaitTimeMillis =
        body.configuration?.startWaitTimeMs?.toInt() ?? defaultWaitTimeMillis;
    final config = LDConfig(
      body.configuration?.credential ?? "",
      AutoEnvAttributes.disabled,
      applicationInfo: body.configuration?.tags?.applicationId != null
          ? ApplicationInfo(
              applicationId: body.configuration!.tags!.applicationId!,
              applicationVersion: body.configuration!.tags!.applicationVersion)
          : null,
      persistence: PersistenceConfig(maxCachedContexts: 0),
      serviceEndpoints: ServiceEndpoints.custom(
          polling: body.configuration?.polling?.baseUri,
          streaming: body.configuration?.streaming?.baseUri,
          events: body.configuration?.events?.baseUri),
      dataSourceConfig: DataSourceConfig(
          initialConnectionMode: body.configuration?.streaming != null
              ? ConnectionMode.streaming
              : ConnectionMode.polling,
          evaluationReasons: body.configuration?.clientSide?.evaluationReasons,
          useReport: body.configuration?.clientSide?.useReport),
      events: EventsConfig(
          eventCapacity: body.configuration?.events?.capacity?.toInt(),
          disabled: body.configuration?.events == null,
          diagnosticOptOut:
              !(body.configuration?.events?.enableDiagnostics ?? true)),
      allAttributesPrivate:
          body.configuration?.events?.allAttributesPrivate ?? false,
      globalPrivateAttributes:
          body.configuration?.events?.globalPrivateAttributes,
    );

    final configuration = body.configuration!;
    final clientSide = configuration.clientSide!;
    final initialContext = clientSide.initialContext!;
    final context = _flattenedListToContext(
        _serializedContextToFlattenedList(initialContext.toJson()));
    final client = LDClient(config, context);
    final started = client.start();
    try {
      await started.timeout(Duration(milliseconds: startWaitTimeMillis));
    } catch (error) {
      // ignore error
    }

    final clientId = nextIdToGive;
    nextIdToGive++;
    clientMap[clientId] = client;

    final Map<String, List<String>> headers = {};
    headers[HttpHeaders.locationHeader] = [
      clientUrlPrefix + clientId.toString()
    ];
    var response = PostResponse.response201();
    response.headers.addAll(headers);
    return response;
  }

  @override
  // ignore: non_constant_identifier_names
  Future<DeleteResponse> Delete() {
    exit(0);
  }

  @override
  Future<ClientIdDeleteResponse> clientIdDelete({required int id}) async {
    var client = clientMap[id];
    if (client != null) {
      client.close();
      return ClientIdDeleteResponse.response200();
    } else {
      return ClientIdDeleteResponse.response404();
    }
  }

  @override
  Future<ClientIdPostResponse> clientIdPost(Request body,
      {required int id}) async {
    final client = clientMap[id];
    if (client == null) {
      return ClientIdPostResponse.response404();
    }

    Response response;
    switch (body.command) {
      case 'identifyEvent':
        response = await _handleIdentifyEvent(client, body);
      case 'evaluate':
        response = _handleEvaluate(client, body);
      case 'evaluateAll':
        response = _handleEvaluateAll(client);
      case 'customEvent':
        response = _handleCustomEvent(client, body);
      case 'flushEvents':
        response = _handleFlushEvents(client);
      case 'contextBuild':
        response = _handleContextBuild(body);
      case 'contextConvert':
        response = _handleContextConvert(body);
      case 'contextComparison':
        response = _handleContextComparison(body);
      default:
        throw UnimplementedError();
    }

    return ClientIdPostResponse.response200(response);
  }

  Future<Response> _handleIdentifyEvent(LDClient client, Request body) async {
    final context = _flattenedListToContext(_serializedContextToFlattenedList(
        body.identifyEvent!.context!.toJson()));
    await client.identify(context);
    return Response();
  }

  Response _handleEvaluate(LDClient client, Request body) {
    final detailRequested = body.evaluate!.detail!;
    final flagKey = body.evaluate!.flagKey!;

    Response response;
    if (detailRequested) {
      switch (body.evaluate!.valueType) {
        case 'bool':
          final result = client.boolVariationDetail(
              flagKey, body.evaluate!['defaultValue'] as bool);
          response = _responseFromEvaluationDetail(LDEvaluationDetail(
              LDValue.ofBool(result.value),
              result.variationIndex,
              result.reason));
        case 'int':
          final result = client.intVariationDetail(
              flagKey, body.evaluate!['defaultValue'] as int);
          response = _responseFromEvaluationDetail(LDEvaluationDetail(
              LDValue.ofNum(result.value),
              result.variationIndex,
              result.reason));
        case 'double':
          final result = client.doubleVariationDetail(
              flagKey, body.evaluate!['defaultValue'] as double);
          response = _responseFromEvaluationDetail(LDEvaluationDetail(
              LDValue.ofNum(result.value),
              result.variationIndex,
              result.reason));
        case 'string':
          final result = client.stringVariationDetail(
              flagKey, body.evaluate!['defaultValue'] as String);
          response = _responseFromEvaluationDetail(LDEvaluationDetail(
              LDValue.ofString(result.value),
              result.variationIndex,
              result.reason));
        default:
          final evalDetail = client.jsonVariationDetail(
              flagKey,
              common.LDValueSerialization.fromJson(
                  body.evaluate!['defaultValue']));
          response = _responseFromEvaluationDetail(evalDetail);
      }
    } else {
      switch (body.evaluate!.valueType) {
        case 'bool':
          response = _responseFromEvaluation(LDValue.ofBool(client
              .boolVariation(flagKey, body.evaluate!['defaultValue'] as bool)));
        case 'int':
          response = _responseFromEvaluation(LDValue.ofNum(client.intVariation(
              flagKey, body.evaluate!['defaultValue'] as int)));
        case 'double':
          response = _responseFromEvaluation(LDValue.ofNum(
              client.doubleVariation(
                  flagKey, body.evaluate!['defaultValue'] as double)));
        case 'string':
          response = _responseFromEvaluation(LDValue.ofString(
              client.stringVariation(
                  flagKey, body.evaluate!['defaultValue'] as String)));
        default:
          response = _responseFromEvaluation(client.jsonVariation(
              flagKey,
              common.LDValueSerialization.fromJson(
                  body.evaluate!['defaultValue'])));
      }
    }

    return response;
  }

  Response _handleEvaluateAll(LDClient client) {
    return _responseFromEvaluateAll(client.allFlags());
  }

  Response _handleCustomEvent(LDClient client, Request body) {
    final eventKey = body.customEvent!.eventKey!;
    final data = common.LDValueSerialization.fromJson(
        body.customEvent!.toJson()['data']);
    final metric = body.customEvent!.metricValue;
    client.track(eventKey, data: data, metricValue: metric);
    return Response();
  }

  Response _handleFlushEvents(LDClient client) {
    client.flush();
    return Response();
  }

  Response _handleContextBuild(Request body) {
    LDContext context = _contextFromSingleOrMulti(body.contextBuild!);
    final response = Response();
    response['output'] = jsonEncode(
        common.LDContextSerialization.toJson(context, isEvent: false));
    return response;
  }

  Response _handleContextConvert(Request body) {
    final response = Response();
    dynamic decoded;
    try {
      decoded = jsonDecode(body.contextConvert!.input!);
      final context =
          _flattenedListToContext(_serializedContextToFlattenedList(decoded));
      if (context.valid) {
        response['output'] = jsonEncode(
            common.LDContextSerialization.toJson(context, isEvent: false));
      } else {
        response['error'] = 'Context was invalid.';
      }
    } catch (error) {
      response['error'] = error.toString();
    }
    return response;
  }

  Response _handleContextComparison(Request body) {
    // ignore: unused_local_variable
    final context1 =
        _contextFromSingleOrMulti(body.contextComparison!.context1!);
    // ignore: unused_local_variable
    final context2 =
        _contextFromSingleOrMulti(body.contextComparison!.context2!);
    final response = Response();
    // TODO: when context comparision support is added, replace 'false' with invocation
    response['equals'] = false;
    return response;
  }

  LDContext _contextFromSingleOrMulti(SingleOrMultiBuildContext input) {
    if (input.single != null) {
      return _flattenedListToContext(
          [_buildContextToFlattenedMap(input.single!)]);
    } else if (input.multi != null) {
      return _flattenedListToContext(
          input.multi!.map((it) => _buildContextToFlattenedMap(it)).toList());
    } else {
      throw UnsupportedError(
          'Expected a single or multi context, but neither were provided.');
    }
  }

  Response _responseFromEvaluationDetail(LDEvaluationDetail<LDValue> detail) {
    return Response.fromJson(
        common.LDEvaluationDetailSerialization.toJson(detail));
  }

  Response _responseFromEvaluation(LDValue value) {
    final response = Response();
    response['value'] = common.LDValueSerialization.toJson(value);
    return response;
  }

  Response _responseFromEvaluateAll(Map<String, LDValue> allFlagsResult) {
    final response = Response();
    response['state'] = allFlagsResult.map((key, value) =>
        MapEntry(key, common.LDValueSerialization.toJson(value)));
    return response;
  }

  // Creates a map representing a single context from the ContextBuild command structure
  Map<String, dynamic> _buildContextToFlattenedMap(BuildContext input) {
    Map<String, dynamic> retMap = {};
    retMap['kind'] = input['kind'];
    retMap['key'] = input['key'];
    retMap['name'] = input['name'];
    retMap['anonymous'] = input['anonymous'];
    if (input['private'] != null) {
      retMap['_meta'] = {'privateAttributes': input['private']};
    }
    retMap.addAll(input['custom'] ?? {});
    return retMap;
  }

  // Creates a flat list of context map representations from the serialized JSON
  List<Map<String, dynamic>> _serializedContextToFlattenedList(
      Map<String, dynamic> json) {
    final retList = <Map<String, dynamic>>[];
    if (json['kind'] == 'multi') {
      for (final entry in json.entries) {
        if (entry.key == 'kind')
          continue; // ignore kind since it was multi and no longer useful

        final single = Map.of(entry.value as Map<String, dynamic>);
        single['kind'] = entry.key;
        retList.add(single);
      }
    } else {
      final single = Map.of(json);
      retList.add(single);
    }

    return retList;
  }

  // Creates a context from a flat list of single context maps.
  LDContext _flattenedListToContext(List<Map<String, dynamic>> flattened) {
    final builder = LDContextBuilder();

    for (final attributes in flattened) {
      final attrsBuilder =
          builder.kind(attributes['kind'] ?? 'user', attributes['key']);
      for (final a in attributes.entries) {
        if (a.key == 'kind' || a.key == 'key') continue;
        attrsBuilder.set(a.key, common.LDValueSerialization.fromJson(a.value));
      }
      final Map<String, dynamic> meta = attributes['_meta'] ?? {};
      final List<String> privateAttrs =
          ((meta['privateAttributes'] ?? []) as List<dynamic>)
              .map((e) => e as String)
              .toList();
      attrsBuilder.addPrivateAttributes(privateAttrs);
    }

    return builder.build();
  }
}

final class _WifiConnected extends ConnectivityPlatform {
  StreamController<ConnectivityResult> _controller = StreamController();
  Stream<ConnectivityResult>? _stream;

  @override
  Future<ConnectivityResult> checkConnectivity() async {
    return ConnectivityResult.wifi;
  }

  @override
  Stream<ConnectivityResult> get onConnectivityChanged {
    if (_stream == null) {
      _stream = _controller.stream.asBroadcastStream();
    }
    return _stream!;
  }
}

void main() async {
  ConnectivityPlatform.instance = _WifiConnected();
  widgets.WidgetsFlutterBinding.ensureInitialized(); // needed before mocking
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({}); // required to mock persistence
  final port = 8080;
  final server = OpenApiShelfServer(
    SdkTestApiRouter(ApiEndpointProvider.static(TestApiImpl())),
  );
  print("Server listening on port $port");
  final process = await server.startServer(port: port);
  await process.exitCode;
}
