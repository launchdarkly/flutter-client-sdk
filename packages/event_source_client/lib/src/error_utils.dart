import 'package:http/http.dart' as http;

import 'http_consts.dart';

/// This class contains static functions for centralizing the logic
/// for which errors are recoverable and which are not.
class ErrorUtils {
  /// This function can be called to determine if we can recover from
  /// the error with the provided HTTP [statusCode]
  static bool isHttpStatusCodeRecoverable(int statusCode) {
    if ((statusCode >= 500 && statusCode < 600) || // 5XX
        statusCode == HttpStatusCodes.badRequestStatus ||
        statusCode == HttpStatusCodes.requestTimeoutStatus ||
        statusCode == HttpStatusCodes.tooManyRequestsStatus) {
      return true;
    }

    return false;
  }

  /// This function can be called to determine if we can recover from
  /// the provided error object.
  static bool isConnectionErrorRecoverable(Object error) {
    if (error is http.ClientException) {
      if (error.message.contains('Redirect loop detected')) {
        return false;
      }
    }

    if (error is StateError) {
      if (error.message
          .contains('Response has no Location header for redirect')) {
        return false;
      }
    }

    // we err on the side of caution and say that errors are recoverable.  The worst
    // thing that happens is we retry wastefully.  The alternative which is to assume
    // errors are NOT recoverable is far worse!
    return true;
  }
}
