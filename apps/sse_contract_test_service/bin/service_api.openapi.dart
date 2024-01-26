// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: prefer_initializing_formals, no_leading_underscores_for_library_prefixes, library_private_types_in_public_api

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:openapi_base/openapi_base.dart';
part 'service_api.openapi.g.dart';

@JsonSerializable()
@ApiUuidJsonConverter()
class ServiceStatusResponse implements OpenApiContent {
  ServiceStatusResponse({this.capabilities});

  factory ServiceStatusResponse.fromJson(Map<String, dynamic> jsonMap) =>
      _$ServiceStatusResponseFromJson(jsonMap);

  @JsonKey(
    name: 'capabilities',
    includeIfNull: false,
  )
  final List<String>? capabilities;

  Map<String, dynamic> toJson() => _$ServiceStatusResponseToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class CreateStreamRequestHeaders implements OpenApiContent {
  CreateStreamRequestHeaders();

  // This type has been manually edited to be a correct string to string map.
  // The generator either omitted all properties with a correctly formed
  // schema, or generated incorrect code with an untyped map.
  factory CreateStreamRequestHeaders.fromJson(Map<String, dynamic> jsonMap) =>
      _$CreateStreamRequestHeadersFromJson(jsonMap)
        .._additionalProperties.addEntries(jsonMap.entries
            .where((e) => !const <String>{}.contains(e.key))
            .map((e) => MapEntry(e.key, e.value.toString())));

  final Map<String, String> _additionalProperties = <String, String>{};

  Map<String, dynamic> toJson() => Map.from(_additionalProperties)
    ..addAll(_$CreateStreamRequestHeadersToJson(this));

  @override
  String toString() => toJson().toString();

  void operator []=(
    String key,
    String value,
  ) =>
      _additionalProperties[key] = value;

  String? operator [](String key) => _additionalProperties[key];
}

@JsonSerializable()
@ApiUuidJsonConverter()
class CreateStreamRequest implements OpenApiContent {
  CreateStreamRequest({
    this.streamUrl,
    this.callbackUrl,
    this.tag,
    this.initialDelayMs,
    this.readTimeoutMs,
    this.lastEventId,
    this.headers,
    this.method,
    this.body,
  });

  factory CreateStreamRequest.fromJson(Map<String, dynamic> jsonMap) =>
      _$CreateStreamRequestFromJson(jsonMap);

  @JsonKey(
    name: 'streamUrl',
    includeIfNull: false,
  )
  final String? streamUrl;

  @JsonKey(
    name: 'callbackUrl',
    includeIfNull: false,
  )
  final String? callbackUrl;

  @JsonKey(
    name: 'tag',
    includeIfNull: false,
  )
  final String? tag;

  @JsonKey(
    name: 'initialDelayMs',
    includeIfNull: false,
  )
  final int? initialDelayMs;

  @JsonKey(
    name: 'readTimeoutMs',
    includeIfNull: false,
  )
  final int? readTimeoutMs;

  @JsonKey(
    name: 'lastEventId',
    includeIfNull: false,
  )
  final String? lastEventId;

  @JsonKey(
    name: 'headers',
    includeIfNull: false,
  )
  final CreateStreamRequestHeaders? headers;

  @JsonKey(
    name: 'method',
    includeIfNull: false,
  )
  final String? method;

  @JsonKey(
    name: 'body',
    includeIfNull: false,
  )
  final String? body;

  Map<String, dynamic> toJson() => _$CreateStreamRequestToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class CommandRequestListen implements OpenApiContent {
  CommandRequestListen({this.type});

  factory CommandRequestListen.fromJson(Map<String, dynamic> jsonMap) =>
      _$CommandRequestListenFromJson(jsonMap);

  @JsonKey(
    name: 'type',
    includeIfNull: false,
  )
  final String? type;

  Map<String, dynamic> toJson() => _$CommandRequestListenToJson(this);

  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class CommandRequest implements OpenApiContent {
  CommandRequest({
    this.command,
    this.listen,
  });

  factory CommandRequest.fromJson(Map<String, dynamic> jsonMap) =>
      _$CommandRequestFromJson(jsonMap);

  @JsonKey(
    name: 'command',
    includeIfNull: false,
  )
  final String? command;

  @JsonKey(
    name: 'listen',
    includeIfNull: false,
  )
  final CommandRequestListen? listen;

  Map<String, dynamic> toJson() => _$CommandRequestToJson(this);

  @override
  String toString() => toJson().toString();
}

class _GetResponse200 extends GetResponse implements OpenApiResponseBodyJson {
  /// Service has started
  _GetResponse200.response200(this.body)
      : status = 200,
        bodyJson = body.toJson();

  @override
  final int status;

  final ServiceStatusResponse body;

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
    implements HasSuccessResponse<ServiceStatusResponse> {
  GetResponse();

  /// Service has started
  factory GetResponse.response200(ServiceStatusResponse body) =>
      _GetResponse200.response200(body);

  void map({required ResponseMap<_GetResponse200> on200}) {
    if (this is _GetResponse200) {
      on200((this as _GetResponse200));
    } else {
      throw StateError('Invalid instance type $this');
    }
  }

  /// status 200:  Service has started
  @override
  ServiceStatusResponse requireSuccess() {
    if (this is _GetResponse200) {
      return (this as _GetResponse200).body;
    } else {
      throw StateError('Expected success response, but got $this');
    }
  }
}

class _PostResponse201 extends PostResponse {
  /// Stream created
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

abstract class PostResponse extends OpenApiResponse
    implements HasSuccessResponse<void> {
  PostResponse();

  /// Stream created
  factory PostResponse.response201() => _PostResponse201.response201();

  void map({required ResponseMap<_PostResponse201> on201}) {
    if (this is _PostResponse201) {
      on201((this as _PostResponse201));
    } else {
      throw StateError('Invalid instance type $this');
    }
  }

  /// status 201:  Stream created
  @override
  void requireSuccess() {
    if (this is _PostResponse201) {
      return;
    } else {
      throw StateError('Expected success response, but got $this');
    }
  }
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

class _ClientIdPostResponse200 extends ClientIdPostResponse {
  /// OK
  _ClientIdPostResponse200.response200() : status = 200;

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

class _ClientIdPostResponse400 extends ClientIdPostResponse {
  /// Unrecognized command
  _ClientIdPostResponse400.response400() : status = 400;

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

class _ClientIdPostResponse404 extends ClientIdPostResponse {
  /// Client not found
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
    implements HasSuccessResponse<void> {
  ClientIdPostResponse();

  /// OK
  factory ClientIdPostResponse.response200() =>
      _ClientIdPostResponse200.response200();

  /// Unrecognized command
  factory ClientIdPostResponse.response400() =>
      _ClientIdPostResponse400.response400();

  /// Client not found
  factory ClientIdPostResponse.response404() =>
      _ClientIdPostResponse404.response404();

  void map({
    required ResponseMap<_ClientIdPostResponse200> on200,
    required ResponseMap<_ClientIdPostResponse400> on400,
    required ResponseMap<_ClientIdPostResponse404> on404,
  }) {
    if (this is _ClientIdPostResponse200) {
      on200((this as _ClientIdPostResponse200));
    } else if (this is _ClientIdPostResponse400) {
      on400((this as _ClientIdPostResponse400));
    } else if (this is _ClientIdPostResponse404) {
      on404((this as _ClientIdPostResponse404));
    } else {
      throw StateError('Invalid instance type $this');
    }
  }

  /// status 200:  OK
  @override
  void requireSuccess() {
    if (this is _ClientIdPostResponse200) {
      return;
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

abstract class TestApi implements ApiEndpoint {
  /// Get service status
  /// get: /
  Future<GetResponse> Get();

  /// Create stream
  /// post: /
  Future<PostResponse> Post(CreateStreamRequest body);

  /// Stop test service
  /// delete: /
  Future<DeleteResponse> Delete();

  /// Send commands to the client.
  /// post: /client/{id}
  Future<ClientIdPostResponse> clientIdPost(
    CommandRequest body, {
    required int id,
  });

  /// Delete client and close connection
  /// delete: /client/{id}
  Future<ClientIdDeleteResponse> clientIdDelete({required int id});
}

abstract class TestApiClient implements OpenApiClient {
  factory TestApiClient(
    Uri baseUri,
    OpenApiRequestSender requestSender,
  ) =>
      _TestApiClientImpl._(
        baseUri,
        requestSender,
      );

  /// Get service status
  /// get: /
  ///
  Future<GetResponse> Get();

  /// Create stream
  /// post: /
  ///
  Future<PostResponse> Post(CreateStreamRequest body);

  /// Stop test service
  /// delete: /
  ///
  Future<DeleteResponse> Delete();

  /// Send commands to the client.
  /// post: /client/{id}
  ///
  Future<ClientIdPostResponse> clientIdPost(
    CommandRequest body, {
    required int id,
  });

  /// Delete client and close connection
  /// delete: /client/{id}
  ///
  Future<ClientIdDeleteResponse> clientIdDelete({required int id});
}

class _TestApiClientImpl extends OpenApiClientBase implements TestApiClient {
  _TestApiClientImpl._(
    this.baseUri,
    this.requestSender,
  );

  @override
  final Uri baseUri;

  @override
  final OpenApiRequestSender requestSender;

  /// Get service status
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
            _GetResponse200.response200(ServiceStatusResponse.fromJson(
                await response.responseBodyJson()))
      },
    );
  }

  /// Create stream
  /// post: /
  ///
  @override
  Future<PostResponse> Post(CreateStreamRequest body) async {
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
            _PostResponse201.response201()
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

  /// Send commands to the client.
  /// post: /client/{id}
  ///
  @override
  Future<ClientIdPostResponse> clientIdPost(
    CommandRequest body, {
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
            _ClientIdPostResponse200.response200(),
        '400': (OpenApiClientResponse response) async =>
            _ClientIdPostResponse400.response400(),
        '404': (OpenApiClientResponse response) async =>
            _ClientIdPostResponse404.response404(),
      },
    );
  }

  /// Delete client and close connection
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

class TestApiUrlResolve with OpenApiUrlEncodeMixin {
  /// Get service status
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

  /// Create stream
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

  /// Send commands to the client.
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

  /// Delete client and close connection
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

class TestApiRouter extends OpenApiServerRouterBase {
  TestApiRouter(this.impl);

  final ApiEndpointProvider<TestApi> impl;

  @override
  void configure() {
    addRoute(
      '/',
      'get',
      (OpenApiRequest request) async {
        return await impl.invoke(
          request,
          (TestApi impl) async => impl.Get(),
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
          (TestApi impl) async => impl.Post(
              CreateStreamRequest.fromJson(await request.readJsonBody())),
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
          (TestApi impl) async => impl.Delete(),
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
          (TestApi impl) async => impl.clientIdPost(
            CommandRequest.fromJson(await request.readJsonBody()),
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
          (TestApi impl) async => impl.clientIdDelete(
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
