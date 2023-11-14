class HttpStatusCodes {
  static const int okStatus = 200;
  static const int badRequestStatus = 400;
  static const int requestTimeoutStatus = 408;
  static const int tooManyRequestsStatus = 429;
}

class HttpHeaders {
  // header fields
  static const authorizationHeader = 'authorization';
  static const userAgentHeader = 'user-agent';
  static const acceptHeader = 'accept';
  static const cacheControlHeader = 'cache-control';
  static const contentTypeHeader = 'content-type';

  // header values
  static const defaultAgentHeaderValue = 'LdDartSSEClient';
  static const noCacheHeaderValue = 'no-cache';
}

class MimeTypes {
  static const textEventStream = 'text/event-stream';
}
