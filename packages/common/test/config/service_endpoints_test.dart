import 'package:launchdarkly_dart_common/src/config/service_endpoints.dart';
import 'package:test/test.dart';

String _defaultPolling = 'polling';
String _defaultStreaming = 'streaming';
String _defaultEvents = 'events';

/// A specific SDK implementation would expose a class that sets
/// the default endpoints for that SDK type. For instance ClientServiceEndpoints.
final class MyEndpoints extends ServiceEndpoints {
  @override
  get defaultPolling => _defaultPolling;

  @override
  get defaultEvents => _defaultEvents;

  @override
  get defaultStreaming => _defaultStreaming;

  /// Construct custom service endpoints.
  ///
  /// In typical SDK usage custom endpoints are not required. When custom
  /// endpoints are required it is recommended that each endpoint is set.
  ///
  /// For debugging purposes a single endpoint may be set, such as using ngrok
  /// to inspect generated events.
  MyEndpoints.custom({super.polling, super.streaming, super.events})
      : super.custom();

  /// Construct service endpoints for use with relay proxy.
  MyEndpoints.relayProxy(super.url) : super.relayProxy();

  /// Construct a default set of service endpoints.
  MyEndpoints() : super();
}

void main() {
  test('can create a default instance', () {
    final endpoints = MyEndpoints();
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.polling, _defaultPolling);
    expect(endpoints.events, _defaultEvents);
  });

  test(
      'if the custom constructor is used, but no endpoints set, it uses defaults',
      () {
    final endpoints = MyEndpoints.custom();
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.polling, _defaultPolling);
    expect(endpoints.events, _defaultEvents);
  });

  test('the polling url can be set', () {
    final endpoints = MyEndpoints.custom(polling: 'customPolling');
    expect(endpoints.polling, 'customPolling');
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.events, _defaultEvents);
  });

  test('the streaming url can be set', () {
    final endpoints = MyEndpoints.custom(streaming: 'customStreaming');
    expect(endpoints.streaming, 'customStreaming');
    expect(endpoints.polling, _defaultPolling);
    expect(endpoints.events, _defaultEvents);
  });

  test('the events url can be set', () {
    final endpoints = MyEndpoints.custom(events: 'customEvents');
    expect(endpoints.events, 'customEvents');
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.polling, _defaultPolling);
  });

  test('all urls can be set', () {
    final endpoints = MyEndpoints.custom(
        polling: 'customPolling',
        streaming: 'customStreaming',
        events: 'customEvents');

    expect(endpoints.events, 'customEvents');
    expect(endpoints.streaming, 'customStreaming');
    expect(endpoints.polling, 'customPolling');
  });

  test('using relay proxy constructor sets all urls', () {
    final endpoints = MyEndpoints.relayProxy('myProxy');

    expect(endpoints.events, 'myProxy');
    expect(endpoints.streaming, 'myProxy');
    expect(endpoints.polling, 'myProxy');
  });

  test('it can do equality comparisons', () {
    expect(MyEndpoints(), MyEndpoints());
    expect(MyEndpoints.custom(), MyEndpoints());

    expect(MyEndpoints.relayProxy('test'),
        MyEndpoints.custom(polling: 'test', streaming: 'test', events: 'test'));

    expect(MyEndpoints.relayProxy('url'), isNot(MyEndpoints()));
  });
}
