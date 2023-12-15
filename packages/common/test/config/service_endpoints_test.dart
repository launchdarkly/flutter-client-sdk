import 'package:test/test.dart';

import 'mock_endpoints.dart';

String _defaultPolling = 'polling';
String _defaultStreaming = 'streaming';
String _defaultEvents = 'events';

void main() {
  test('can create a default instance', () {
    final endpoints = MockEndpoints();
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.polling, _defaultPolling);
    expect(endpoints.events, _defaultEvents);
  });

  test(
      'if the custom constructor is used, but no endpoints set, it uses defaults',
      () {
    final endpoints = MockEndpoints.custom();
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.polling, _defaultPolling);
    expect(endpoints.events, _defaultEvents);
  });

  test('the polling url can be set', () {
    final endpoints = MockEndpoints.custom(polling: 'customPolling');
    expect(endpoints.polling, 'customPolling');
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.events, _defaultEvents);
  });

  test('the streaming url can be set', () {
    final endpoints = MockEndpoints.custom(streaming: 'customStreaming');
    expect(endpoints.streaming, 'customStreaming');
    expect(endpoints.polling, _defaultPolling);
    expect(endpoints.events, _defaultEvents);
  });

  test('the events url can be set', () {
    final endpoints = MockEndpoints.custom(events: 'customEvents');
    expect(endpoints.events, 'customEvents');
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.polling, _defaultPolling);
  });

  test('all urls can be set', () {
    final endpoints = MockEndpoints.custom(
        polling: 'customPolling',
        streaming: 'customStreaming',
        events: 'customEvents');

    expect(endpoints.events, 'customEvents');
    expect(endpoints.streaming, 'customStreaming');
    expect(endpoints.polling, 'customPolling');
  });

  test('using relay proxy constructor sets all urls', () {
    final endpoints = MockEndpoints.relayProxy('myProxy');

    expect(endpoints.events, 'myProxy');
    expect(endpoints.streaming, 'myProxy');
    expect(endpoints.polling, 'myProxy');
  });

  test('it can do equality comparisons', () {
    expect(MockEndpoints(), MockEndpoints());
    expect(MockEndpoints.custom(), MockEndpoints());

    expect(
        MockEndpoints.relayProxy('test'),
        MockEndpoints.custom(
            polling: 'test', streaming: 'test', events: 'test'));

    expect(MockEndpoints.relayProxy('url'), isNot(MockEndpoints()));
  });
}
