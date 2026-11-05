/// [launchdarkly_sse] provides SSE streaming functionality.
library launchdarkly_sse;

import 'dart:async';
import 'dart:collection';

import 'src/http_consts.dart';
import 'src/logging.dart';
import 'src/events.dart';
import 'src/sse_client_stub.dart'
    if (dart.library.io) 'src/sse_client_http.dart'
    if (dart.library.js_interop) 'src/sse_client_html.dart';
import 'src/sse_client_http.dart' as http_client show HttpSseClient;
import 'src/test_sse_client.dart';

export 'src/errors.dart' show SseHttpError;
export 'src/events.dart' show Event, MessageEvent, OpenEvent;
export 'src/test_sse_client.dart' show TestSseClient;
export 'src/logging.dart'
    show EventSourceLogger, LogLevel, NoOpLogger, PrintLogger;

/// Optional behaviors that an [SSEClient] implementation may or may not
/// support. Callers query support with [SSEClient.hasCapability] and
/// route around missing capabilities (for example, by switching to a
/// query-parameter form of authentication when the transport cannot
/// send custom request headers).
///
/// Modeled as a class with private-constructor static-const instances
/// rather than an enum so adding a new capability is source-compatible
/// for users -- a `switch (capability)` over an enum becomes
/// non-exhaustive when a new value is added.
class SSECapability {
  /// The capability identifier. Stable across releases and intended
  /// only for diagnostics; comparisons should use the static const
  /// members directly (e.g. `cap == SSECapability.requestHeaders`).
  final String value;

  const SSECapability._(this.value);

  /// The transport can send custom request headers. False for the
  /// browser native `EventSource` API; true for HTTP-based clients.
  static const SSECapability requestHeaders = SSECapability._('requestHeaders');

  @override
  String toString() => 'SSECapability.$value';
}

/// True when compiled for a browser.
const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');

/// Default headers of [SSEClient.http] on web. Only CORS-safelisted headers.
const Map<String, String> _webDefaultHeaders = {
  HttpHeaders.acceptHeader: MimeTypes.textEventStream,
};

/// HTTP methods supported by the event source client.
enum SseHttpMethod {
  get('GET'),
  report('REPORT'),
  post('POST');

  final String _value;

  const SseHttpMethod(this._value);

  @override
  String toString() {
    return _value;
  }
}

/// An [SSEClient] that works to maintain a SSE connection to a server.
///
/// You can receive [Events]s by listening to the [stream] object. The SSEClient
/// will connect when there is a nonzero number of subscribers on the [stream]
/// and will disconnect when there are zero subscribers on the [stream].
/// In certain cases, unrecoverable errors will be reported on the [stream] at
/// which point the stream will be done.
///
/// On `html` platforms the default client is incapable of reporting
/// unrecoverable errors: the browser's native `EventSource` exposes no HTTP
/// status codes or response headers, so every failure is treated as
/// recoverable and retried with backoff indefinitely, and no error is ever
/// reported on the [stream]. The client from [SSEClient.http] does not have
/// this limit. On web, it sees a status code only when the CORS policy of the
/// server allows it. A response that fails a CORS check is a recoverable
/// connection error, not an [SseHttpError].
///
/// The [SSEClient] will make best effort to maintain the streaming connection.
abstract class SSEClient {
  static const defaultHeaders = <String, String>{
    HttpHeaders.userAgentHeader: HttpHeaders.defaultAgentHeaderValue,
    HttpHeaders.acceptHeader: MimeTypes.textEventStream,
    HttpHeaders.cacheControlHeader: HttpHeaders.noCacheHeaderValue,
  };
  static const defaultConnectTimeout = Duration(seconds: 30);
  static const defaultReadTimeout = Duration(minutes: 5);

  /// Subscribe to this [stream] to receive events and sometimes errors.
  /// subscribe triggers the connection, so expect network delay initially.
  Stream<Event> get stream;

  /// Closes the SSEClient and tears down connections and resources.  Do not use the
  /// SSEClient after close is called, behavior is undefined at that point.
  Future close();

  /// Request that the SSEClient drops the current connection and then
  /// establishes a new connection respecting delay/backoff as if this was
  /// an error condition with the connection.
  void restart();

  /// Whether this implementation supports the given [capability]. Lets
  /// callers detect transport limitations at runtime — for example, the
  /// browser native `EventSource` does not support
  /// [SSECapability.requestHeaders], so callers that need to authenticate
  /// must fall back to a URL-based scheme.
  ///
  /// The default implementation returns `false` for every capability so
  /// adding a new capability constant (or adding this method to an
  /// existing external implementation) is source-compatible. Concrete
  /// implementations should override and report what they actually
  /// support.
  bool hasCapability(SSECapability capability) => false;

  /// Factory constructor to return the platform implementation.
  ///
  /// On all platforms, the [uri] and [eventTypes] arguments are required.
  /// On majority of platforms, the optional arguments are used. On web,
  /// the [headers], [connectTimeout], [readTimeout], [body], and
  /// [httpMethod] arguments are not used; the standard `EventSource`
  /// does not support them.
  ///
  /// The [uri] specifies where to connect.  The [eventTypes] determines which
  /// event types will be emitted.  For non-web platforms, pass in [headers] to
  /// customize the HTTP headers of the connection request.  The [connectTimeout]
  /// is how long to try establishing the connection and the [readTimeout] is how
  /// long the connection can be silent before it is torn down.
  ///
  /// An optional [body]. It is recommended only to use the body with `REPORT`
  /// or `POST` methods. A `GET` accompanied by a body is non-standard. On `html`
  /// platforms the body will be ignored, as the `html` implementation uses
  /// the standard `EventSource` which does not support a body.
  ///
  /// An optional [httpMethod], if not included then the `GET` method will be
  /// used. On `html` platforms the httpMethod will be ignored, as the `html`
  /// implementation uses the standard `EventSource` which only uses `GET`.
  ///
  /// An optional [logger] for controlling logging output from the SSE client.
  /// If not provided, a [NoOpLogger] will be used.
  ///
  /// An optional [uriProvider]. When provided, it is invoked before every
  /// connection attempt -- the first connect and each automatic
  /// reconnect -- and its result is used for that attempt; [uri] is used
  /// only when no provider is given. This allows query parameters to
  /// vary between attempts (e.g. a state selector that advances as data
  /// is received). Supported on all platforms.
  factory SSEClient(Uri uri, Set<String> eventTypes,
      {Map<String, String> headers = defaultHeaders,
      Duration connectTimeout = defaultConnectTimeout,
      Duration readTimeout = defaultReadTimeout,
      String? body,
      SseHttpMethod httpMethod = SseHttpMethod.get,
      EventSourceLogger? logger,
      Uri Function()? uriProvider}) {
    // merge headers so consumer gets reasonable defaults
    final mergedHeaders = <String, String>{...defaultHeaders, ...headers};
    return getSSEClient(uri, eventTypes, mergedHeaders, connectTimeout,
        readTimeout, body, httpMethod.toString(), logger, uriProvider);
  }

  /// Factory constructor that always returns the HTTP-based implementation,
  /// on every platform including web.
  ///
  /// On web, the [SSEClient] default factory uses the browser native
  /// `EventSource`, which cannot send a request body, an HTTP method other
  /// than `GET`, or custom headers, and which cannot report HTTP errors.
  /// This constructor uses `package:http`, which streams with `fetch()` in
  /// the browser, so it supports all of these. Use it when an application
  /// needs those features on web.
  ///
  /// On web, a custom header must be allowed by the CORS configuration of
  /// the server, or the browser blocks the request. For this reason, on web
  /// the default headers are only `accept`. The `user-agent` header is
  /// forbidden in browsers, and `cache-control` is not CORS-safelisted, so
  /// each would force a preflight request. This matches the browser SDKs.
  /// Any header in [headers] is still sent.
  ///
  /// The [headers], [connectTimeout], [readTimeout], [body], [httpMethod] and
  /// [uriProvider] arguments are used on every platform. The other arguments
  /// have the same meaning as in the default factory.
  factory SSEClient.http(Uri uri, Set<String> eventTypes,
      {Map<String, String> headers = const {},
      Duration connectTimeout = defaultConnectTimeout,
      Duration readTimeout = defaultReadTimeout,
      String? body,
      SseHttpMethod httpMethod = SseHttpMethod.get,
      EventSourceLogger? logger,
      Uri Function()? uriProvider}) {
    final mergedHeaders = <String, String>{
      ..._isWeb ? _webDefaultHeaders : defaultHeaders,
      ...headers
    };
    return http_client.HttpSseClient(uri, eventTypes, mergedHeaders,
        connectTimeout, readTimeout, body, httpMethod.toString(), logger,
        uriProvider: uriProvider);
  }

  /// Get an SSE client for use in unit tests.
  ///
  /// Most parameters are the same as those of the main SSEClient factory, but
  /// the test client supports an additional property which is the [sourceStream].
  /// Events sent to the [sourceStream] will also be emitted by the event source
  /// if the event source has listeners. When a user unsubscribes from the event
  /// stream, then the test client will unsubscribe from the source stream.
  ///
  /// This method is primarily for use the the LaunchDarkly SDK implementation.
  /// Changes may be made to this API without following semantic conventions.
  static TestSseClient testClient(
    Uri uri,
    Set<String> eventTypes, {
    Map<String, String> headers = defaultHeaders,
    Duration connectTimeout = defaultConnectTimeout,
    Duration readTimeout = defaultReadTimeout,
    String? body,
    SseHttpMethod httpMethod = SseHttpMethod.get,
    Stream<Event>? sourceStream,
    Set<SSECapability>? capabilities,
  }) {
    return TestSseClient.internal(
        headers: UnmodifiableMapView(headers),
        connectTimeout: connectTimeout,
        readTimeout: readTimeout,
        body: body,
        httpMethod: httpMethod,
        sourceStream: sourceStream,
        capabilities: capabilities);
  }
}
