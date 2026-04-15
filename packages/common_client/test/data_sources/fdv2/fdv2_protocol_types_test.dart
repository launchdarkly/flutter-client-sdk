import 'package:launchdarkly_common_client/src/data_sources/fdv2/fdv2_protocol_types.dart';
import 'package:test/test.dart';

void main() {
  group('IntentCode', () {
    test('fromWire parses known values', () {
      expect(IntentCode.fromWire('xfer-full'), equals(IntentCode.xferFull));
      expect(
          IntentCode.fromWire('xfer-changes'), equals(IntentCode.xferChanges));
      expect(IntentCode.fromWire('none'), equals(IntentCode.none));
    });

    test('fromWire returns null for unknown values', () {
      expect(IntentCode.fromWire('unknown'), isNull);
      expect(IntentCode.fromWire(null), isNull);
    });
  });

  group('ServerIntentData', () {
    test('fromJson parses payloads', () {
      final data = ServerIntentData.fromJson({
        'payloads': [
          {
            'id': 'p1',
            'target': 42,
            'intentCode': 'xfer-full',
            'reason': 'payload-missing',
          }
        ]
      });
      expect(data.payloads, hasLength(1));
      expect(data.payloads[0].id, equals('p1'));
      expect(data.payloads[0].target, equals(42));
      expect(data.payloads[0].intentCode, equals(IntentCode.xferFull));
      expect(data.payloads[0].reason, equals('payload-missing'));
    });

    test('fromJson handles missing payloads', () {
      final data = ServerIntentData.fromJson({});
      expect(data.payloads, isEmpty);
    });
  });

  group('PutObjectEvent (top-level)', () {
    test('fromJson parses all fields', () {
      final event = PutObjectEvent.fromJson({
        'kind': 'flag-eval',
        'key': 'my-flag',
        'version': 5,
        'object': {'value': true},
      });
      expect(event.kind, equals('flag-eval'));
      expect(event.key, equals('my-flag'));
      expect(event.version, equals(5));
      expect(event.object!['value'], equals(true));
    });
  });

  group('DeleteObjectEvent (top-level)', () {
    test('fromJson parses all fields', () {
      final event = DeleteObjectEvent.fromJson({
        'kind': 'flag-eval',
        'key': 'deleted-flag',
        'version': 3,
      });
      expect(event.kind, equals('flag-eval'));
      expect(event.key, equals('deleted-flag'));
      expect(event.version, equals(3));
    });
  });

  group('PayloadTransferredEvent (top-level)', () {
    test('fromJson parses all fields', () {
      final event = PayloadTransferredEvent.fromJson({
        'state': '(p:abc:42)',
        'version': 42,
      });
      expect(event.state, equals('(p:abc:42)'));
      expect(event.version, equals(42));
    });
  });

  group('PayloadIntent', () {
    test('fromJson preserves null for missing target', () {
      final intent = PayloadIntent.fromJson({
        'id': 'p1',
        'intentCode': 'none',
        'reason': 'up-to-date',
      });
      expect(intent.target, isNull);
    });

    test('fromJson preserves null for unknown intentCode', () {
      final intent = PayloadIntent.fromJson({
        'id': 'p1',
        'target': 42,
        'intentCode': 'xfer-future-unknown',
        'reason': 'test',
      });
      expect(intent.intentCode, isNull);
    });

    test('fromJson preserves null for missing intentCode', () {
      final intent = PayloadIntent.fromJson({
        'id': 'p1',
        'target': 42,
        'reason': 'test',
      });
      expect(intent.intentCode, isNull);
    });
  });

  group('PutObjectEvent', () {
    test('fromJson preserves null for missing version', () {
      final event = PutObjectEvent.fromJson({
        'kind': 'flag-eval',
        'key': 'my-flag',
        'object': {'value': true},
      });
      expect(event.version, isNull);
    });

    test('fromJson preserves null for missing object', () {
      final event = PutObjectEvent.fromJson({
        'kind': 'flag-eval',
        'key': 'my-flag',
        'version': 1,
      });
      expect(event.object, isNull);
    });
  });

  group('DeleteObjectEvent', () {
    test('fromJson preserves null for missing version', () {
      final event = DeleteObjectEvent.fromJson({
        'kind': 'flag-eval',
        'key': 'my-flag',
      });
      expect(event.version, isNull);
    });
  });

  group('PayloadTransferredEvent', () {
    test('fromJson preserves null for missing version', () {
      final event = PayloadTransferredEvent.fromJson({
        'state': 'sel-1',
      });
      expect(event.version, isNull);
    });
  });

  group('GoodbyeEvent', () {
    test('fromJson parses all fields', () {
      final event = GoodbyeEvent.fromJson({
        'reason': 'maintenance',
        'silent': true,
      });
      expect(event.reason, equals('maintenance'));
      expect(event.silent, isTrue);
    });

    test('fromJson handles defaults', () {
      final event = GoodbyeEvent.fromJson({'reason': 'bye'});
      expect(event.silent, isFalse);
    });
  });

  group('ServerErrorEvent', () {
    test('fromJson parses all fields', () {
      final event = ServerErrorEvent.fromJson({
        'payload_id': 'p1',
        'reason': 'something broke',
      });
      expect(event.payloadId, equals('p1'));
      expect(event.reason, equals('something broke'));
    });
  });

  group('FDv2EventsCollection', () {
    test('fromJson parses events array', () {
      final collection = FDv2EventsCollection.fromJson({
        'events': [
          {
            'event': 'server-intent',
            'data': {
              'payloads': [
                {'id': 'p1', 'target': 1, 'intentCode': 'xfer-full', 'reason': 'test'}
              ]
            }
          },
          {
            'event': 'put-object',
            'data': {'kind': 'flag-eval', 'key': 'f1', 'version': 1, 'object': {}}
          },
        ]
      });
      expect(collection.events, hasLength(2));
      expect(collection.events[0].event, equals('server-intent'));
      expect(collection.events[1].event, equals('put-object'));
    });

    test('fromJson handles missing events', () {
      final collection = FDv2EventsCollection.fromJson({});
      expect(collection.events, isEmpty);
    });
  });
}
