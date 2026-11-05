import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

final class _Logger implements EventSourceLogger {
  final List<String> messages = [];

  @override
  void debug(String message) => messages.add(message);

  @override
  void info(String message) => messages.add(message);

  @override
  void warn(String message) => messages.add(message);

  @override
  void error(String message) => messages.add(message);
}

/// Names every SSE type that the SDK exports for a factory author. The test
/// does not compile when the SDK stops exporting one of them.
void main() {
  test('the SSE types for a factory author are exported', () {
    final logger = _Logger();
    SSEClient build(SSEClientRequest request) =>
        SSEClient.http(request.uriProvider(), request.eventTypes,
            headers: request.headers,
            body: request.body,
            httpMethod: request.method,
            logger: logger,
            uriProvider: request.uriProvider);
    final SSEClientFactory factory = build;
    const capabilities = {
      SSECapability.customMethod,
      SSECapability.httpErrors,
      SSECapability.requestHeaders,
    };
    const error = SseHttpError(401, {}, recoverable: false);
    const method = SseHttpMethod.report;

    expect(factory, same(build));
    expect(capabilities, hasLength(3));
    expect(error.statusCode, 401);
    expect(method, isNot(SseHttpMethod.get));
  });
}
