import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'selector.dart';

/// FDv2 endpoint paths.
///
/// These paths are uniform across mobile and browser SDKs; FDv2 does
/// not distinguish between platforms at the endpoint level.
abstract final class FDv2Endpoints {
  /// Polling path. Used as-is for POST requests (context sent in the
  /// request body) and as the prefix for GET requests via [pollingGet].
  static const String polling = '/sdk/poll/eval';

  /// Streaming path. Used as-is for POST requests (context sent in the
  /// request body) and as the prefix for GET requests via [streamingGet].
  static const String streaming = '/sdk/stream/eval';

  /// Builds the polling GET path with the base64url-encoded context
  /// embedded in the URL path.
  static String pollingGet(String encodedContext) => '$polling/$encodedContext';

  /// Builds the streaming GET path with the base64url-encoded context
  /// embedded in the URL path.
  static String streamingGet(String encodedContext) =>
      '$streaming/$encodedContext';
}

/// Builds an FDv2 request URI: appends [addedPath] to [baseUri]'s path and
/// merges the [withReasons], [basis], and [additionalQueryParameters]
/// query parameters onto the base URL's own.
///
/// Composes against the parsed [baseUri] so a custom URL carrying its own
/// query parameters (e.g. a relay proxy with a token) is preserved --
/// including repeated keys, via `queryParametersAll`, which a plain
/// `queryParameters` map would collapse to the last value. String
/// concatenation against the base would instead land the appended path
/// inside the query component.
///
/// Shared by the polling requestor and the streaming source so the two
/// transports build URLs identically.
Uri buildFDv2Uri({
  required Uri baseUri,
  required String addedPath,
  required bool withReasons,
  required Selector basis,
  Map<String, String> additionalQueryParameters = const {},
}) {
  final mergedPath = appendPath(baseUri.path, addedPath);
  final mergedQuery = <String, dynamic>{}
    ..addAll(baseUri.queryParametersAll)
    ..addAll(additionalQueryParameters);
  if (withReasons) {
    mergedQuery['withReasons'] = 'true';
  }
  if (basis.state case final state? when state.isNotEmpty) {
    mergedQuery['basis'] = state;
  }
  return baseUri.replace(
    path: mergedPath,
    queryParameters: mergedQuery.isEmpty ? null : mergedQuery,
  );
}
