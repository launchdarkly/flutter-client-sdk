// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: prefer_initializing_formals, no_leading_underscores_for_library_prefixes, library_private_types_in_public_api

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:openapi_base/openapi_base.dart';
part 'callback_api.openapi.g.dart';

@JsonSerializable()
@ApiUuidJsonConverter()
class PostCallbackEvent implements OpenApiContent {
  PostCallbackEvent({
    this.type,
    this.data,
    this.id,
  });

  factory PostCallbackEvent.fromJson(Map<String, dynamic> jsonMap) =>
      _$PostCallbackEventFromJson(jsonMap);

  @JsonKey(
    name: 'type',
    includeIfNull: false,
  )
  final String? type;

  @JsonKey(
    name: 'data',
    includeIfNull: false,
  )
  final String? data;

  @JsonKey(
    name: 'id',
    includeIfNull: false,
  )
  final String? id;

  Map<String, dynamic> toJson() => _$PostCallbackEventToJson(this);
  @override
  String toString() => toJson().toString();
}

@JsonSerializable()
@ApiUuidJsonConverter()
class PostCallback implements OpenApiContent {
  PostCallback({
    this.kind,
    this.comment,
    this.event,
  });

  factory PostCallback.fromJson(Map<String, dynamic> jsonMap) =>
      _$PostCallbackFromJson(jsonMap);

  @JsonKey(
    name: 'kind',
    includeIfNull: false,
  )
  final String? kind;

  @JsonKey(
    name: 'comment',
    includeIfNull: false,
  )
  final String? comment;

  @JsonKey(
    name: 'event',
    includeIfNull: false,
  )
  final PostCallbackEvent? event;

  Map<String, dynamic> toJson() => _$PostCallbackToJson(this);
  @override
  String toString() => toJson().toString();
}

class _CallbackNumberPostResponse202 extends CallbackNumberPostResponse {
  /// Callback accepted
  _CallbackNumberPostResponse202.response202() : status = 202;

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

abstract class CallbackNumberPostResponse extends OpenApiResponse
    implements HasSuccessResponse<void> {
  CallbackNumberPostResponse();

  /// Callback accepted
  factory CallbackNumberPostResponse.response202() =>
      _CallbackNumberPostResponse202.response202();

  void map({required ResponseMap<_CallbackNumberPostResponse202> on202}) {
    if (this is _CallbackNumberPostResponse202) {
      on202((this as _CallbackNumberPostResponse202));
    } else {
      throw StateError('Invalid instance type $this');
    }
  }

  /// status 202:  Callback accepted
  @override
  void requireSuccess() {
    if (this is _CallbackNumberPostResponse202) {
      return;
    } else {
      throw StateError('Expected success response, but got $this');
    }
  }
}

abstract class CallbackApi implements ApiEndpoint {
  /// Send callback
  /// post: /{callbackNumber}
  Future<CallbackNumberPostResponse> callbackNumberPost(
    PostCallback body, {
    required int callbackNumber,
  });
}

abstract class CallbackApiClient implements OpenApiClient {
  factory CallbackApiClient(
    Uri baseUri,
    OpenApiRequestSender requestSender,
  ) =>
      _CallbackApiClientImpl._(
        baseUri,
        requestSender,
      );

  /// Send callback
  /// post: /{callbackNumber}
  ///
  Future<CallbackNumberPostResponse> callbackNumberPost(
    PostCallback body, {
    required int callbackNumber,
  });
}

class _CallbackApiClientImpl extends OpenApiClientBase
    implements CallbackApiClient {
  _CallbackApiClientImpl._(
    this.baseUri,
    this.requestSender,
  );

  @override
  final Uri baseUri;

  @override
  final OpenApiRequestSender requestSender;

  /// Send callback
  /// post: /{callbackNumber}
  ///
  @override
  Future<CallbackNumberPostResponse> callbackNumberPost(
    PostCallback body, {
    required int callbackNumber,
  }) async {
    final request = OpenApiClientRequest(
      'post',
      '/{callbackNumber}',
      [],
    );
    request.addPathParameter(
      'callbackNumber',
      encodeInt(callbackNumber),
    );
    request.setHeader(
      'content-type',
      'application/json',
    );
    request.setBody(OpenApiClientRequestBodyJson(body.toJson()));
    return await sendRequest(
      request,
      {
        '202': (OpenApiClientResponse response) async =>
            _CallbackNumberPostResponse202.response202()
      },
    );
  }
}

class CallbackApiUrlResolve with OpenApiUrlEncodeMixin {
  /// Send callback
  /// post: /{callbackNumber}
  ///
  OpenApiClientRequest callbackNumberPost({required int callbackNumber}) {
    final request = OpenApiClientRequest(
      'post',
      '/{callbackNumber}',
      [],
    );
    request.addPathParameter(
      'callbackNumber',
      encodeInt(callbackNumber),
    );
    return request;
  }
}

class CallbackApiRouter extends OpenApiServerRouterBase {
  CallbackApiRouter(this.impl);

  final ApiEndpointProvider<CallbackApi> impl;

  @override
  void configure() {
    addRoute(
      '/{callbackNumber}',
      'post',
      (OpenApiRequest request) async {
        return await impl.invoke(
          request,
          (CallbackApi impl) async => impl.callbackNumberPost(
            PostCallback.fromJson(await request.readJsonBody()),
            callbackNumber: paramRequired(
              name: 'callbackNumber',
              value: request.pathParameter('callbackNumber'),
              decode: (value) => paramToInt(value),
            ),
          ),
        );
      },
      security: [],
    );
  }
}

class SecuritySchemes {}

T _throwStateError<T>(String message) => throw StateError(message);
