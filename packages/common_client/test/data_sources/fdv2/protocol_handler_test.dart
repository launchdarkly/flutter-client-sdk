import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/protocol_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/protocol_types.dart';
import 'package:test/test.dart';

void main() {
  final logger = LDLogger();

  FDv2ProtocolHandler makeHandler() {
    return FDv2ProtocolHandler(
      objProcessors: {
        'flag-eval': (obj) => obj,
      },
      logger: logger,
    );
  }

  FDv2Event serverIntent(String intentCode,
      {int target = 1, String id = 'test-id'}) {
    return FDv2Event(event: FDv2EventTypes.serverIntent, data: {
      'payloads': [
        {
          'id': id,
          'target': target,
          'intentCode': intentCode,
          'reason': 'test',
        }
      ]
    });
  }

  FDv2Event putObject(String key,
      {String kind = 'flag-eval',
      int version = 1,
      Map<String, dynamic>? object}) {
    return FDv2Event(event: FDv2EventTypes.putObject, data: {
      'kind': kind,
      'key': key,
      'version': version,
      'object': object ?? {'value': true, 'version': version},
    });
  }

  FDv2Event deleteObject(String key,
      {String kind = 'flag-eval', int version = 1}) {
    return FDv2Event(event: FDv2EventTypes.deleteObject, data: {
      'kind': kind,
      'key': key,
      'version': version,
    });
  }

  FDv2Event payloadTransferred({String state = 'test-state', int version = 1}) {
    return FDv2Event(event: FDv2EventTypes.payloadTransferred, data: {
      'state': state,
      'version': version,
    });
  }

  group('initial state', () {
    test('starts in inactive state', () {
      final handler = makeHandler();
      expect(handler.state, equals(ProtocolState.inactive));
    });
  });

  group('server-intent', () {
    test('xfer-full sets state to full', () {
      final handler = makeHandler();
      final action = handler.processEvent(serverIntent('xfer-full'));
      expect(action, isA<ActionNone>());
      expect(handler.state, equals(ProtocolState.full));
    });

    test('xfer-changes sets state to changes', () {
      final handler = makeHandler();
      final action = handler.processEvent(serverIntent('xfer-changes'));
      expect(action, isA<ActionNone>());
      expect(handler.state, equals(ProtocolState.changes));
    });

    test('none emits a payload with type none', () {
      final handler = makeHandler();
      final action = handler.processEvent(serverIntent('none', target: 42));
      expect(action, isA<ActionPayload>());
      final payload = (action as ActionPayload).payload;
      expect(payload.type, equals(PayloadType.none));
      expect(payload.updates, isEmpty);
      expect(payload.selector.isEmpty, isTrue);
    });

    test('empty payloads array returns error', () {
      final handler = makeHandler();
      final action = handler.processEvent(FDv2Event(
          event: FDv2EventTypes.serverIntent, data: {'payloads': []}));
      expect(action, isA<ActionError>());
      expect((action as ActionError).kind,
          equals(ProtocolErrorKind.missingPayload));
    });

    test('missing payloads field returns error', () {
      final handler = makeHandler();
      final action = handler.processEvent(
          FDv2Event(event: FDv2EventTypes.serverIntent, data: {}));
      expect(action, isA<ActionError>());
    });

    test('unknown intentCode returns none without emitting payload', () {
      final handler = makeHandler();
      final action = handler
          .processEvent(FDv2Event(event: FDv2EventTypes.serverIntent, data: {
        'payloads': [
          {
            'id': 'p1',
            'target': 42,
            'intentCode': 'xfer-future-unknown',
            'reason': 'test',
          }
        ]
      }));
      expect(action, isA<ActionNone>());
    });

    test('unknown intentCode clears stale updates', () {
      final handler = makeHandler();
      // Start a transfer and accumulate an update.
      handler.processEvent(serverIntent('xfer-full'));
      handler.processEvent(putObject('stale-flag'));

      // Unknown intent code arrives — should clear accumulated updates.
      handler.processEvent(FDv2Event(event: FDv2EventTypes.serverIntent, data: {
        'payloads': [
          {
            'id': 'p1',
            'target': 1,
            'intentCode': 'xfer-future-unknown',
            'reason': 'test',
          }
        ]
      }));

      // Now a valid transfer completes — stale update must not appear.
      handler.processEvent(putObject('fresh-flag'));
      final action = handler.processEvent(payloadTransferred(state: 'sel-1'));
      expect(action, isA<ActionPayload>());
      final payload = (action as ActionPayload).payload;
      expect(payload.updates, hasLength(1));
      expect(payload.updates[0].key, equals('fresh-flag'));
    });

    test('none intent with missing target returns none', () {
      final handler = makeHandler();
      final action = handler
          .processEvent(FDv2Event(event: FDv2EventTypes.serverIntent, data: {
        'payloads': [
          {
            'id': 'p1',
            'intentCode': 'none',
            'reason': 'up-to-date',
          }
        ]
      }));
      // Should return ActionNone, NOT a payload with version: 0
      expect(action, isA<ActionNone>());
    });
  });

  group('put-object', () {
    test('accumulates put before payload-transferred', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));

      final action = handler.processEvent(putObject('flag-1'));
      expect(action, isA<ActionNone>());
    });

    test('ignored before server-intent', () {
      final handler = makeHandler();
      final action = handler.processEvent(putObject('flag-1'));
      expect(action, isA<ActionNone>());
    });

    test('ignored for unknown kind with no processor', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      handler.processEvent(FDv2Event(event: FDv2EventTypes.putObject, data: {
        'kind': 'unknown-kind',
        'key': 'test',
        'version': 1,
        'object': {'value': true}
      }));

      // Verify the unknown-kind update is NOT in the emitted payload.
      final action = handler.processEvent(payloadTransferred(state: 'sel-1'));
      expect(action, isA<ActionPayload>());
      final payload = (action as ActionPayload).payload;
      expect(payload.updates, isEmpty);
    });

    test('ignored with empty key', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      final action = handler
          .processEvent(FDv2Event(event: FDv2EventTypes.putObject, data: {
        'kind': 'flag-eval',
        'key': '',
        'version': 1,
        'object': {'value': true}
      }));
      expect(action, isA<ActionNone>());
    });

    test('ignored with missing version', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      final action = handler
          .processEvent(FDv2Event(event: FDv2EventTypes.putObject, data: {
        'kind': 'flag-eval',
        'key': 'my-flag',
        'object': {'value': true}
      }));
      expect(action, isA<ActionNone>());
    });

    test('ignored with missing object', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      final action = handler
          .processEvent(FDv2Event(event: FDv2EventTypes.putObject, data: {
        'kind': 'flag-eval',
        'key': 'my-flag',
        'version': 1,
      }));
      expect(action, isA<ActionNone>());
    });

    test('ignored when ObjProcessor returns null', () {
      final handler = FDv2ProtocolHandler(
        objProcessors: {
          'flag-eval': (obj) => null,
        },
        logger: LDLogger(),
      );
      handler.processEvent(serverIntent('xfer-full'));
      handler.processEvent(putObject('flag-1'));

      // Verify the update is NOT in the emitted payload.
      final action = handler.processEvent(payloadTransferred(state: 'sel-1'));
      expect(action, isA<ActionPayload>());
      final payload = (action as ActionPayload).payload;
      expect(payload.updates, isEmpty);
    });

    test('known kind accumulates while unknown kind is ignored', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      handler.processEvent(putObject('known-flag', kind: 'flag-eval'));
      handler.processEvent(FDv2Event(event: FDv2EventTypes.putObject, data: {
        'kind': 'segment',
        'key': 'some-segment',
        'version': 1,
        'object': {'key': 'seg-1'}
      }));

      final action = handler.processEvent(payloadTransferred(state: 'sel-1'));
      expect(action, isA<ActionPayload>());
      final payload = (action as ActionPayload).payload;
      expect(payload.updates, hasLength(1));
      expect(payload.updates[0].key, equals('known-flag'));
    });
  });

  group('delete-object', () {
    test('accumulates delete before payload-transferred', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-changes'));

      final action = handler.processEvent(deleteObject('flag-1'));
      expect(action, isA<ActionNone>());
    });

    test('ignored before server-intent', () {
      final handler = makeHandler();
      final action = handler.processEvent(deleteObject('flag-1'));
      expect(action, isA<ActionNone>());
    });

    test('ignored with missing version', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-changes'));
      final action = handler
          .processEvent(FDv2Event(event: FDv2EventTypes.deleteObject, data: {
        'kind': 'flag-eval',
        'key': 'my-flag',
      }));
      expect(action, isA<ActionNone>());
    });

    test('ignored for unknown kind', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-changes'));
      handler.processEvent(FDv2Event(event: FDv2EventTypes.deleteObject, data: {
        'kind': 'segment',
        'key': 'some-segment',
        'version': 1,
      }));

      // Verify the unknown-kind delete is NOT in the emitted payload.
      final action = handler.processEvent(payloadTransferred(state: 'sel-1'));
      expect(action, isA<ActionPayload>());
      final payload = (action as ActionPayload).payload;
      expect(payload.updates, isEmpty);
    });
  });

  group('payload-transferred', () {
    test('emits full payload with accumulated updates', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      handler.processEvent(putObject('flag-1', version: 5));
      handler.processEvent(deleteObject('flag-2', version: 6));

      final action =
          handler.processEvent(payloadTransferred(state: 'sel-1', version: 10));
      expect(action, isA<ActionPayload>());

      final payload = (action as ActionPayload).payload;
      expect(payload.type, equals(PayloadType.full));
      expect(payload.selector.state, equals('sel-1'));
      expect(payload.selector.version, equals(10));
      expect(payload.updates, hasLength(2));
      expect(payload.updates[0].key, equals('flag-1'));
      expect(payload.updates[0].deleted, isFalse);
      expect(payload.updates[1].key, equals('flag-2'));
      expect(payload.updates[1].deleted, isTrue);
    });

    test('emits partial payload for xfer-changes', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-changes'));
      handler.processEvent(putObject('flag-1'));

      final action = handler.processEvent(payloadTransferred(state: 'sel-2'));
      expect(action, isA<ActionPayload>());

      final payload = (action as ActionPayload).payload;
      expect(payload.type, equals(PayloadType.partial));
    });

    test('resets to changes state after emission', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      handler.processEvent(payloadTransferred(state: 'sel-1'));
      expect(handler.state, equals(ProtocolState.changes));
    });

    test('error when received in inactive state', () {
      final handler = makeHandler();
      final action = handler.processEvent(payloadTransferred());
      expect(action, isA<ActionError>());
      expect((action as ActionError).kind,
          equals(ProtocolErrorKind.protocolError));
    });

    test('ignored with empty state', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      final action = handler.processEvent(FDv2Event(
          event: FDv2EventTypes.payloadTransferred,
          data: {'state': '', 'version': 1}));
      expect(action, isA<ActionNone>());
      // Should have reset to inactive
      expect(handler.state, equals(ProtocolState.inactive));
    });

    test('ignored with missing version', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      final action = handler.processEvent(FDv2Event(
          event: FDv2EventTypes.payloadTransferred, data: {'state': 'sel-1'}));
      expect(action, isA<ActionNone>());
      expect(handler.state, equals(ProtocolState.inactive));
    });

    test('subsequent payload after xfer-full is partial', () {
      final handler = makeHandler();
      // First transfer: full
      handler.processEvent(serverIntent('xfer-full'));
      handler.processEvent(putObject('flag-1'));
      handler.processEvent(payloadTransferred(state: 'sel-1'));

      // Second transfer (no new server-intent): partial
      handler.processEvent(putObject('flag-2'));
      final action = handler.processEvent(payloadTransferred(state: 'sel-2'));
      expect(action, isA<ActionPayload>());
      final payload = (action as ActionPayload).payload;
      expect(payload.type, equals(PayloadType.partial));
      expect(payload.updates, hasLength(1));
    });
  });

  group('goodbye', () {
    test('returns goodbye action and resets', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));

      final action = handler.processEvent(FDv2Event(
          event: FDv2EventTypes.goodbye, data: {'reason': 'maintenance'}));
      expect(action, isA<ActionGoodbye>());
      expect((action as ActionGoodbye).reason, equals('maintenance'));
      expect(handler.state, equals(ProtocolState.inactive));
    });
  });

  group('error', () {
    test('returns server error action and discards temp updates', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      handler.processEvent(putObject('flag-1'));

      final action = handler.processEvent(FDv2Event(
          event: FDv2EventTypes.error,
          data: {'payload_id': 'p1', 'reason': 'oops'}));
      expect(action, isA<ActionServerError>());
      expect((action as ActionServerError).reason, equals('oops'));
      expect(action.id, equals('p1'));

      // State should still be full (not reset to inactive),
      // but temp updates should be cleared. New data can follow.
      expect(handler.state, equals(ProtocolState.full));
    });
  });

  group('heartbeat', () {
    test('returns none', () {
      final handler = makeHandler();
      final action = handler
          .processEvent(FDv2Event(event: FDv2EventTypes.heartbeat, data: {}));
      expect(action, isA<ActionNone>());
    });
  });

  group('unknown event', () {
    test('returns error action', () {
      final handler = makeHandler();
      final action =
          handler.processEvent(FDv2Event(event: 'unknown-type', data: {}));
      expect(action, isA<ActionError>());
      expect(
          (action as ActionError).kind, equals(ProtocolErrorKind.unknownEvent));
    });
  });

  group('reset', () {
    test('resets state to inactive', () {
      final handler = makeHandler();
      handler.processEvent(serverIntent('xfer-full'));
      expect(handler.state, equals(ProtocolState.full));

      handler.reset();
      expect(handler.state, equals(ProtocolState.inactive));
    });
  });

  group('full transfer sequence', () {
    test('complete xfer-full with puts and deletes', () {
      final handler = makeHandler();

      // Server intent
      handler.processEvent(serverIntent('xfer-full', target: 50));

      // Data
      handler.processEvent(putObject('flag-a', version: 1, object: {
        'value': true,
        'version': 1,
        'variation': 0,
        'trackEvents': false,
      }));
      handler.processEvent(putObject('flag-b', version: 2, object: {
        'value': 'hello',
        'version': 2,
        'variation': 1,
        'trackEvents': true,
      }));
      handler.processEvent(deleteObject('flag-c', version: 3));

      // Complete
      final action = handler
          .processEvent(payloadTransferred(state: '(p:abc:50)', version: 50));
      expect(action, isA<ActionPayload>());

      final payload = (action as ActionPayload).payload;
      expect(payload.type, equals(PayloadType.full));
      expect(payload.selector.state, equals('(p:abc:50)'));
      expect(payload.selector.version, equals(50));
      expect(payload.updates, hasLength(3));

      expect(payload.updates[0].kind, equals('flag-eval'));
      expect(payload.updates[0].key, equals('flag-a'));
      expect(payload.updates[0].deleted, isFalse);

      expect(payload.updates[2].kind, equals('flag-eval'));
      expect(payload.updates[2].key, equals('flag-c'));
      expect(payload.updates[2].deleted, isTrue);
    });
  });
}
