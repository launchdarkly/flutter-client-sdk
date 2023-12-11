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
  if(status == 413) {
    return true;
  }
  return isHttpGloballyRecoverable(status);
}
