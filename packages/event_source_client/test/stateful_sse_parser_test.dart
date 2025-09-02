import 'dart:async';

import 'package:launchdarkly_event_source_client/src/events.dart';
import 'package:launchdarkly_event_source_client/src/stateful_sse_parser.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class MockSink extends Mock implements EventSink<Event> {}

void main() {
  setUpAll(() {
    registerFallbackValue(MessageEvent('fallback', 'fallback', 'fallback'));
  });

  void testCase(String input, List<Event> expected) {
    final parserUnderTest = StatefulSSEParser();
    final mockSink = MockSink();
    parserUnderTest.parse(input, mockSink);

    final captured = verify(() => mockSink.add(captureAny())).captured;

    expect(captured.length, equals(expected.length),
        reason: 'Captured:{$captured}, Expected:{$expected}');

    for (var i = 0; i < captured.length; i++) {
      expect(expected[i], isA<MessageEvent>());
      final expectedMessageEvent = expected[i] as MessageEvent;
      final messageEvent = captured[i] as MessageEvent;
      expect(messageEvent, isA<MessageEvent>());
      expect(messageEvent.type, equals(expectedMessageEvent.type));
      expect(messageEvent.data, equals(expectedMessageEvent.data));
      expect(messageEvent.id, equals(expectedMessageEvent.id));
    }
  }

  test('Test cases', () {
    final cases = {
      // one event
      'event:patch\ndata:hello\n\n': [MessageEvent('patch', 'hello', '')],
      // two events
      'event:patch\ndata:hello\n\nevent:put\ndata:world\n\n': [
        MessageEvent('patch', 'hello', ''),
        MessageEvent('put', 'world', '')
      ],
      // no event type
      'data: testtest\n\ndata:test\n\n': [
        MessageEvent('message', 'testtest', ''),
        MessageEvent('message', 'test', '')
      ],
      // id
      'event: greeting\nid: abc\ndata: Hello\n\n': [
        MessageEvent('greeting', 'Hello', 'abc')
      ],
      // leading colon ignores line
      '::::data: ignored\n\ndata:test\n\n': [
        MessageEvent('message', 'test', '')
      ],
      // leading newlines are ignored
      '\r\n\r\n\ndata: testtest\n\ndata:test\n\n': [
        MessageEvent('message', 'testtest', ''),
        MessageEvent('message', 'test', '')
      ],
      // premature termination of field is ignored
      'ignored\n\ndata:test\n\n': [MessageEvent('message', 'test', '')],
      // extra leading space
      'event:  greeting\ndata:  Hello\n\n': [
        MessageEvent(' greeting', ' Hello', '')
      ],
    };
    cases.forEach(testCase);
  });
}
