import 'package:launchdarkly_dart_client/ld_client.dart';
import 'package:launchdarkly_dart_client/src/config/defaults/default_config.dart';
import 'package:test/test.dart';

final String _defaultStreaming = DefaultConfig.endpoints.streaming;
final String _defaultPolling = DefaultConfig.endpoints.polling;
final String _defaultEvents = DefaultConfig.endpoints.events;

void main() {
  test('can create a default instance', () {
    final endpoints = ServiceEndpoints();
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.polling, _defaultPolling);
    expect(endpoints.events, _defaultEvents);
  });

  test(
      'if the custom constructor is used, but no endpoints set, it uses defaults',
      () {
    final endpoints = ServiceEndpoints.custom();
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.polling, _defaultPolling);
    expect(endpoints.events, _defaultEvents);
  });

  test('the polling url can be set', () {
    final endpoints = ServiceEndpoints.custom(polling: 'customPolling');
    expect(endpoints.polling, 'customPolling');
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.events, _defaultEvents);
  });

  test('the streaming url can be set', () {
    final endpoints = ServiceEndpoints.custom(streaming: 'customStreaming');
    expect(endpoints.streaming, 'customStreaming');
    expect(endpoints.polling, _defaultPolling);
    expect(endpoints.events, _defaultEvents);
  });

  test('the events url can be set', () {
    final endpoints = ServiceEndpoints.custom(events: 'customEvents');
    expect(endpoints.events, 'customEvents');
    expect(endpoints.streaming, _defaultStreaming);
    expect(endpoints.polling, _defaultPolling);
  });

  test('all urls can be set', () {
    final endpoints = ServiceEndpoints.custom(
        polling: 'customPolling',
        streaming: 'customStreaming',
        events: 'customEvents');

    expect(endpoints.events, 'customEvents');
    expect(endpoints.streaming, 'customStreaming');
    expect(endpoints.polling, 'customPolling');
  });

  test('using relay proxy constructor sets all urls', () {
    final endpoints = ServiceEndpoints.relayProxy('myProxy');

    expect(endpoints.events, 'myProxy');
    expect(endpoints.streaming, 'myProxy');
    expect(endpoints.polling, 'myProxy');
  });

  test('it can do equality comparisons', () {
    expect(ServiceEndpoints(), ServiceEndpoints());
    expect(ServiceEndpoints.custom(), ServiceEndpoints());

    expect(
        ServiceEndpoints.relayProxy('test'),
        ServiceEndpoints.custom(
            polling: 'test', streaming: 'test', events: 'test'));

    expect(ServiceEndpoints.relayProxy('url'), isNot(ServiceEndpoints()));
  });
}
