/// [launchdarkly_sse] provides SSE streaming functionality.
library launchdarkly_sse;

import 'dart:async';

import 'src/http_consts.dart';
import 'src/message_event.dart';
import 'src/sse_client_stub.dart'
    if (dart.library.io) 'src/sse_client_http.dart'
    if (dart.library.html) 'src/sse_client_html.dart';

export 'src/message_event.dart' show MessageEvent;

// TODO: sc-157779 - add general logging
// TODO: around alpha phase - need the backoff jitter around web client to prevent
// flooding cloud servers on service interruption
// TODO: sc-217248 - add REPORT functionality

/// An [SSEClient] that works to maintain a SSE connection to a server.
///
/// You can receive [MessageEvent]s by listening to the [stream] object.  The SSEClient will
/// connect when there is a nonzero number of subscribers on [stream] and will disconnect when
/// there are zero subscribers on [stream].  In certain cases, unrecoverable errors will be
/// reported on the [stream] at which point the stream will be done.
///
/// The [SSEClient] will make best effort to maintain the streaming connection.
abstract class SSEClient {
  static const defaultHeaders = <String, String>{
    HttpHeaders.userAgentHeader: HttpHeaders.defaultAgentHeaderValue,
    HttpHeaders.acceptHeader: MimeTypes.textEventStream,
    HttpHeaders.cacheControlHeader: HttpHeaders.noCacheHeaderValue,
  };
  static const defaultConnectTimeout = const Duration(seconds: 30);
  static const defaultReadTimeout = const Duration(minutes: 5);

  /// Subscribe to this [stream] to receive events and sometimes errors.  The first
  /// subscribe triggers the connection, so expect network delay initially.
  Stream<MessageEvent> get stream;

  /// Closes the SSEClient and tears down connections and resources.  Do not use the
  /// SSEClient after close is called, behavior is undefined at that point.
  Future close();

  /// Factory constructor to return the platform implementation.
  ///
  /// On all platforms, the [uri] and [eventTypes] arguments are required.
  /// On majority of platforms, the optional arguments are used.
  /// On web, the optional arguments are not used.
  ///
  /// The [uri] specifies where to connect.  The [eventTypes] determines which
  /// event types will be emitted.  For non-web platforms, pass in [headers] to
  /// customize the HTTP headers of the connection request.  The [connectTimeout]
  /// is how long to try establishing the connection and the [readTimeout] is how
  /// long the connection can be silent before it is torn down.
  factory SSEClient(Uri uri, Set<String> eventTypes,
      {Map<String, String> headers = defaultHeaders,
      Duration connectTimeout = defaultConnectTimeout,
      Duration readTimeout = defaultReadTimeout}) {
    // merge headers so consumer gets reasonable defaults
    var mergedHeaders = <String, String>{};
    mergedHeaders.addAll(defaultHeaders);
    mergedHeaders.addAll(headers);
    return getSSEClient(
        uri, eventTypes, mergedHeaders, connectTimeout, readTimeout);
  }
}
