import '../launchdarkly_event_source_client.dart';
import 'http_consts.dart';

/// True when compiled for a browser.
const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');

/// The default headers of [SSEClient.http] on web.
///
/// A browser forbids the `user-agent` header, so it is left out. The
/// `cache-control` header stops a browser from serving a cached stream
/// response on a reconnect. It is not CORS-safelisted, so the browser sends
/// a preflight request, which the server must allow. The LaunchDarkly
/// streaming service allows it. The LaunchDarkly browser SDK sends the same
/// headers.
const Map<String, String> webDefaultHeaders = {
  HttpHeaders.acceptHeader: MimeTypes.textEventStream,
  HttpHeaders.cacheControlHeader: HttpHeaders.noCacheHeaderValue,
};

/// Returns the request headers of [SSEClient.http]: the default headers of
/// the platform, with [headers] on top.
Map<String, String> httpSseClientHeaders(Map<String, String> headers) => {
      ...(_isWeb ? webDefaultHeaders : SSEClient.defaultHeaders),
      ...headers,
    };
