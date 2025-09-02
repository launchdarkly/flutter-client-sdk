// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:launchdarkly_event_source_client/src/http_consts.dart';
import 'package:launchdarkly_event_source_client/src/events.dart';
import 'package:launchdarkly_event_source_client/src/state_value_object.dart';

class TestUtils {
  static const String defaultUri = '/path';
  static const Set<String> defaultEventTypes = {};
  static const Map<String, String> defaultHeaders = {
    HttpHeaders.contentTypeHeader: MimeTypes.textEventStream
  };

  static StateValues makeMockStateValues(
      {Uri? uri,
      Set<String>? eventTypes,
      Map<String, String>? headers,
      Duration? connectTimeout,
      Duration? readTimeout,
      Stream<bool>? connectionDesired,
      EventSink<Event>? eventSink,
      Sink<dynamic>? transitionSink,
      ClientFactory? clientFactory,
      math.Random? random,
      Stream<void>? resetStream}) {
    return StateValues(
        uri ?? Uri.parse(defaultUri),
        eventTypes ?? defaultEventTypes,
        headers ?? defaultHeaders,
        connectTimeout ?? Duration.zero,
        readTimeout ?? Duration.zero,
        connectionDesired ?? StreamController<bool>.broadcast().stream,
        eventSink ?? StreamController<Event>.broadcast(),
        transitionSink ?? StreamController<dynamic>.broadcast(),
        clientFactory ?? makeMockHttpClient,
        math.Random(),
        null,
        'GET',
        resetStream ?? StreamController<void>.broadcast().stream);
  }

  static MockClient makeMockHttpClient(
      {int httpStatusCode = HttpStatusCodes.okStatus,
      Map<String, String> headers = defaultHeaders,
      bool blocking = false}) {
    return MockClient.streaming((request, bodyStream) async {
      return bodyStream.bytesToString().then((bodyString) async {
        if (blocking) {
          await Completer().future; // blocks indefinitely
        }
        var controller = StreamController<List<int>>(sync: true);
        Future.sync(() {
          controller.add(utf8.encode('event:put\ndata:helloworld\n\n'));
        });
        return StreamedResponse(controller.stream, httpStatusCode,
            headers: headers);
      });
    });
  }
}
