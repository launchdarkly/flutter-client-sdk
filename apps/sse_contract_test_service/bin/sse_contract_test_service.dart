import 'dart:async';

import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:openapi_base/openapi_base.dart';
import 'callback_api.openapi.dart';
import 'service_api.openapi.dart';
import 'dart:io';

class TestApiImpl extends TestApi {
  static const _clientUrlPrefix = "/client/";

  final Map<int, StreamSubscription> _clientSubMap = {};
  final Map<int, SSEClient> _clientMap = {};
  var _nextIdToGive = 0;

  @override
  Future<GetResponse> Get() async {
    const capabilities = <String>['report', 'post', 'headers', 'restart'];
    return GetResponse.response200(
        ServiceStatusResponse(capabilities: capabilities));
  }

  @override
  Future<PostResponse> Post(CreateStreamRequest body) async {
    // set up callback mechanisms
    final callbackSender = HttpRequestSender();
    var callbackId = 1;
    final callbackClient =
        CallbackApiClient(Uri.parse(body.callbackUrl!), callbackSender);

    // create a new streaming client
    final streamUri = Uri.parse(body.streamUrl!);

    SseHttpMethod method;

    switch (body.method) {
      case 'REPORT':
        method = SseHttpMethod.report;
      case 'POST':
        method = SseHttpMethod.post;
      default:
        method = SseHttpMethod.get;
    }

    final headers = <String, String>{};

    if (body.headers != null) {
      headers.addAll(body.headers!.toJson().map(
          (key, value) => MapEntry<String, String>(key, value.toString())));
    }

    // TODO: it would be nice if we didn't have to specify all the event types, but because the web
    // event source must specify them, we are doomed to this purgatory.
    final client = SSEClient(
        streamUri,
        {
          'put',
          'patch',
          'delete',
          'message',
          'greeting',
          ' greeting',
        },
        body: body.body,
        httpMethod: method,
        headers: headers);
    final subscription = client.stream.listen((event) {
      callbackClient.callbackNumberPost(
          PostCallback(
              kind: 'event',
              event: PostCallbackEvent(
                  type: event.type, data: event.data, id: event.id)),
          callbackNumber: callbackId);
      callbackId++;
    }, onError: (error) {
      callbackClient.callbackNumberPost(
          PostCallback(kind: 'error', comment: error.toString()),
          callbackNumber: callbackId);
      callbackId++;
    });

    final clientId = _nextIdToGive;
    _clientSubMap[clientId] = subscription;
    _clientMap[clientId] = client;
    _nextIdToGive++;

    final Map<String, List<String>> responseHeaders = {};
    responseHeaders[HttpHeaders.locationHeader] = [
      _clientUrlPrefix + clientId.toString()
    ];
    var response = PostResponse.response201();
    response.headers.addAll(responseHeaders);
    return response;
  }

  @override
  Future<DeleteResponse> Delete() {
    exit(0);
  }

  @override
  Future<ClientIdDeleteResponse> clientIdDelete({required int id}) async {
    var subscription = _clientSubMap[id];
    if (subscription != null) {
      subscription.cancel();
      _clientSubMap.remove(id);
      _clientMap.remove(id);
      return ClientIdDeleteResponse.response200();
    } else {
      return ClientIdDeleteResponse.response404();
    }
  }

  @override
  Future<ClientIdPostResponse> clientIdPost(CommandRequest body,
      {required int id}) async {
    if (!_clientSubMap.containsKey(id)) {
      return ClientIdPostResponse.response404();
    }
    switch (body.command) {
      case 'restart':
        _clientMap[id]?.restart();
        return ClientIdPostResponse.response200();
      default:
        return ClientIdPostResponse.response400();
    }
  }
}

void main(List<String> args) async {
  final port = 8080;
  final server = OpenApiShelfServer(
    TestApiRouter(ApiEndpointProvider.static(TestApiImpl())),
  );
  print("Server listening on port $port");
  server.startServer(port: port);
}
