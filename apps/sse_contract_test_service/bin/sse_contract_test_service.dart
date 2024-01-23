import 'dart:async';

import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:openapi_base/openapi_base.dart';
import 'callback_api.openapi.dart';
import 'service_api.openapi.dart';
import 'dart:io';

class TestApiImpl extends TestApi {
  static const clientUrlPrefix = "/client/";

  final Map<int, StreamSubscription> clientSubMap = {};
  var nextIdToGive = 0;

  @override
  Future<GetResponse> Get() async {
    return GetResponse.response200(ServiceStatusResponse());
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

    // TODO: it would be nice if we didn't have to specify all the event types, but because the web
    // event source must specify them, we are doomed to this purgatory.
    final subscription = SSEClient(streamUri, {
      'put',
      'patch',
      'delete',
      'message',
      'greeting',
      ' greeting'
    }).stream.listen((event) {
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

    final clientId = nextIdToGive;
    // TODO: Uncomment as part of sc-215077
    clientSubMap[clientId] = subscription;
    nextIdToGive++;

    final Map<String, List<String>> headers = {};
    headers[HttpHeaders.locationHeader] = [
      clientUrlPrefix + clientId.toString()
    ];
    var response = PostResponse.response201();
    response.headers.addAll(headers);
    return response;
  }

  @override
  Future<DeleteResponse> Delete() {
    exit(0);
  }

  @override
  Future<ClientIdDeleteResponse> clientIdDelete({required int id}) async {
    var subscription = clientSubMap[id];
    if (subscription != null) {
      subscription.cancel();
      return ClientIdDeleteResponse.response200();
    } else {
      return ClientIdDeleteResponse.response404();
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
