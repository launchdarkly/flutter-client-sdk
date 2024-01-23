import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../launchdarkly_dart_common.dart';

/// Filter a set of headers to remove any headers that are not allowed.
///
/// This is primarily for web where a number of headers are forbidden from
/// modification by JavaScript.
///
Map<String, String> filterHeaders(
    Set<String> forbidden, Map<String, String> headers) {
  Map<String, String> filteredHeaders = {};

  for (var entry in headers.entries) {
    if (!forbidden.contains(entry.key)) {
      filteredHeaders[entry.key] = entry.value;
    }
  }

  return filteredHeaders;
}

/// Creates header map from application info, omitting any properties that
/// are missing.
extension Headers on ApplicationInfo {
  Map<String, String> asHeaderMap() {
    final tags = <String>[];
    // tags should be added in alphabetical order
    if (applicationId != null) {
      tags.add('application-id/${applicationId!}');
    }

    if (applicationName != null) {
      tags.add('application-name/${applicationName!}');
    }

    if (applicationVersion != null) {
      tags.add('application-version/${applicationVersion!}');
    }

    if (applicationVersionName != null) {
      tags.add('application-version-name/${applicationVersionName!}');
    }

    return {'X-LaunchDarkly-Tags': tags.join(' ')};
  }
}

/// Appends a path to a URL or existing url+path. The path should start with
/// a '/'. If the base includes a trailing '/', then it will be removed.
String appendPath(String base, String path) {
  if (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  return '$base$path';
}

/// Check if the HTTP error is recoverable. This will return false if a request
/// made with any payload could not recover. If the reason for the failure
/// is payload specific, for instance a payload that is too large, then
/// it could recover with a different payload.
bool isHttpGloballyRecoverable(num status) {
  if (status >= 400 && status < 500) {
    return status == 400 || status == 408 || status == 429;
  }
  return true;
}

/// Returns true if the status could recover for a different payload.
///
/// When used with event processing this indicates that we should discard
/// the payload, but that a subsequent payload may succeed. Therefore we should
/// not stop event processing.
bool isHttpLocallyRecoverable(num status) {
  if (status == 413) {
    return true;
  }
  return isHttpGloballyRecoverable(status);
}

/// Hashes the input, base64 encodes result, then sanitizes it for URL usage.
String urlSafeSha256Hash(String input) {
  return _encodeAndSanitize(sha256.convert(utf8.encode(input)).bytes);
}

/// Base64 encodes input and then sanitizes it for URL usage.
String urlSafeBase64String(String input) {
  return _encodeAndSanitize(utf8.encode(input));
}

/// Base64 encodes input and then sanitizes it for URL usage.
String _encodeAndSanitize(List<int> input) {
  return base64.encode(input).replaceAll('+', '-').replaceAll('/', '_');
}
