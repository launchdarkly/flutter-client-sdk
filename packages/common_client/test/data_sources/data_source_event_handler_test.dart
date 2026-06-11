import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:test/test.dart';

void main() {
  final logger = LDLogger();

  group('given data source event handler', () {
    DataSourceEventHandler? eventHandler;
    DataSourceStatusManager? statusManager;
    FlagManager? flagManager;
    final context = LDContextBuilder().kind('user', 'user-key').build();

    setUp(() {
      flagManager =
          FlagManager(sdkKey: 'the-key', maxCachedContexts: 4, logger: logger);
      var time = 0;
      statusManager = DataSourceStatusManager(stamper: () {
        time++;
        return DateTime(time);
      });
      eventHandler = DataSourceEventHandler(
          flagManager: flagManager!,
          statusManager: statusManager!,
          logger: logger);
    });

    test('it handles a put message without reasons', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(2))));

      expectLater(flagManager!.changes,
          emits(FlagsChangedEvent(keys: ['HasBob', 'killswitch'])));

      eventHandler!.handleMessage(
          context,
          'put',
          '{"HasBob":{"version":11,"flagVersion":5,"value":false,"variation":1,'
              '"trackEvents":false},'
              '"killswitch":{"version":10,"flagVersion":4,"value":true,'
              '"variation":0,"trackEvents":false}'
              '}');

      final bob = flagManager!.get('HasBob')!.flag!;
      expect(bob.version, 11);
      expect(bob.detail.value, LDValue.ofBool(false));
      expect(bob.detail.variationIndex, 1);
      expect(bob.detail.reason, isNull);

      final killSwitch = flagManager!.get('killswitch')!.flag!;
      expect(killSwitch.version, 10);
      expect(killSwitch.detail.value, LDValue.ofBool(true));
      expect(killSwitch.detail.variationIndex, 0);
      expect(killSwitch.detail.reason, isNull);
    });

    test('it handles a put message with reasons', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(2))));

      expectLater(flagManager!.changes,
          emits(FlagsChangedEvent(keys: ['HasBob', 'killswitch'])));

      eventHandler!.handleMessage(
          context,
          'put',
          '{"HasBob":{"version":11,"flagVersion":5,"value":false,"variation":1,'
              '"trackEvents":false,"reason":{"kind":"FALLTHROUGH"}},'
              '"killswitch":{"version":10,"flagVersion":4,"value":true,'
              '"variation":0,"trackEvents":false,"reason":{"kind":"FALLTHROUGH"}}}');

      final bob = flagManager!.get('HasBob')!.flag!;
      expect(bob.version, 11);
      expect(bob.detail.value, LDValue.ofBool(false));
      expect(bob.detail.variationIndex, 1);
      expect(bob.detail.reason, LDEvaluationReason.fallthrough());

      final killSwitch = flagManager!.get('killswitch')!.flag!;
      expect(killSwitch.version, 10);
      expect(killSwitch.detail.value, LDValue.ofBool(true));
      expect(killSwitch.detail.variationIndex, 0);
      expect(killSwitch.detail.reason, LDEvaluationReason.fallthrough());
    });

    test('it handles a put message with environment ID', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(2))));

      expectLater(
          flagManager!.changes, emits(FlagsChangedEvent(keys: ['HasBob'])));

      eventHandler!.handleMessage(
          context,
          'put',
          '{"HasBob":{"version":11,"flagVersion":5,"value":false,"variation":1,'
              '"trackEvents":false}}',
          environmentId: 'test-env-123');

      final bob = flagManager!.get('HasBob')!.flag!;
      expect(bob.version, 11);
      expect(bob.detail.value, LDValue.ofBool(false));
      expect(bob.detail.variationIndex, 1);

      // Verify environment ID was set in flag store
      expect(flagManager!.environmentId, 'test-env-123');
    });

    test('it handles a put message without environment ID', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(2))));

      expectLater(
          flagManager!.changes, emits(FlagsChangedEvent(keys: ['HasBob'])));

      eventHandler!.handleMessage(
          context,
          'put',
          '{"HasBob":{"version":11,"flagVersion":5,"value":false,"variation":1,'
              '"trackEvents":false}}');

      final bob = flagManager!.get('HasBob')!.flag!;
      expect(bob.version, 11);
      expect(bob.detail.value, LDValue.ofBool(false));
      expect(bob.detail.variationIndex, 1);

      // Environment ID should be null when not provided
      expect(flagManager!.environmentId, null);
    });

    test('it can handle bad json on PUT', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              lastError: DataSourceStatusErrorInfo(
                  kind: ErrorKind.invalidData,
                  message: 'Could not parse PUT message',
                  statusCode: null,
                  time: DateTime(2)),
              state: DataSourceState.initializing,
              stateSince: DateTime(1))));

      eventHandler!.handleMessage(
          context, 'put', '{"HasBob":{"ve#%()#*()*{"kind":"FALLTHROUGH"}}}');
    });

    test('it can handle bad json on PATCH', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              lastError: DataSourceStatusErrorInfo(
                  kind: ErrorKind.invalidData,
                  message: 'Could not parse PATCH message',
                  statusCode: null,
                  time: DateTime(2)),
              state: DataSourceState.initializing,
              stateSince: DateTime(1))));

      eventHandler!.handleMessage(
          context, 'patch', '{"HasBob":{"ve#%()#*()*{"kind":"FALLTHROUGH"}}}');
    });

    test('it can handle bad json on DELETE', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              lastError: DataSourceStatusErrorInfo(
                  kind: ErrorKind.invalidData,
                  message: 'Could not parse DELETE message',
                  statusCode: null,
                  time: DateTime(2)),
              state: DataSourceState.initializing,
              stateSince: DateTime(1))));

      eventHandler!.handleMessage(
          context, 'delete', '{"HasBob":{"ve#%()#*()*{"kind":"FALLTHROUGH"}}}');
    });

    test('it can handle an invalid, but well formed on PUT, payload', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              lastError: DataSourceStatusErrorInfo(
                  kind: ErrorKind.invalidData,
                  message: 'PUT message contained invalid data',
                  statusCode: null,
                  time: DateTime(2)),
              state: DataSourceState.initializing,
              stateSince: DateTime(1))));

      eventHandler!.handleMessage(context, 'put', '{"HasBob":17}');
    });

    test('it can handle an invalid, but well formed on PATCH, payload', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              lastError: DataSourceStatusErrorInfo(
                  kind: ErrorKind.invalidData,
                  message: 'PATCH message contained invalid data',
                  statusCode: null,
                  time: DateTime(2)),
              state: DataSourceState.initializing,
              stateSince: DateTime(1))));

      eventHandler!.handleMessage(context, 'patch', '{"HasBob":17}');
    });

    test('it can handle an invalid, but well formed on DELETE, payload', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              lastError: DataSourceStatusErrorInfo(
                  kind: ErrorKind.invalidData,
                  message: 'DELETE message contained invalid data',
                  statusCode: null,
                  time: DateTime(2)),
              state: DataSourceState.initializing,
              stateSince: DateTime(1))));

      eventHandler!.handleMessage(context, 'delete', '{"HasBob":17}');
    });

    group('given a handler which has received a put', () {
      setUp(() async {
        await eventHandler!.handleMessage(
            context,
            'put',
            '{"my-boolean-flag":{"version":11,"flagVersion":5,"value":false,"variation":1,'
                '"trackEvents":false},'
                '"killswitch":{"version":10,"flagVersion":4,"value":true,'
                '"variation":0,"trackEvents":false}'
                '}');
      });

      test('it handles a PATCH message without reasons', () async {
        expect(
            await eventHandler!.handleMessage(
                context,
                'patch',
                '{"key": "my-boolean-flag", "version": 681, "flagVersion": 53,'
                    ' "value": true, "variation": 1, "trackEvents": false}'),
            MessageStatus.messageHandled);

        final updated = flagManager!.get('my-boolean-flag')!;
        expect(updated.version, 681);
        expect(updated.flag!.detail.value.booleanValue(), true);
      });

      test('it handles a PATCH message with reasons', () async {
        expect(
            await eventHandler!.handleMessage(
                context,
                'patch',
                '{"key":"my-boolean-flag","version":681,"flagVersion":56,'
                    '"value":true,"variation":0,"trackEvents":false,'
                    '"reason":{"kind":"FALLTHROUGH"}}'),
            MessageStatus.messageHandled);

        final updated = flagManager!.get('my-boolean-flag')!;
        expect(updated.version, 681);
        expect(updated.flag!.detail.value.booleanValue(), true);
        expect(updated.flag!.detail.reason, LDEvaluationReason.fallthrough());
      });

      test('it handles a DELETE message', () async {
        expect(
            await eventHandler!.handleMessage(
                context, 'delete', '{"key":"my-boolean-flag","version":681}'),
            MessageStatus.messageHandled);

        final updated = flagManager!.get('my-boolean-flag')!;
        expect(updated.version, 681);
        expect(updated.flag, isNull);
      });
    });

    group('handlePayload', () {
      Update flagEval(String key, int version, {Object? value = true}) =>
          Update(
            kind: 'flag-eval',
            key: key,
            version: version,
            object: {
              'flagVersion': 5,
              'value': value,
              'variation': 0,
              'trackEvents': false,
            },
          );

      test('a full payload replaces the stored flags and sets valid', () async {
        expectLater(
            statusManager!.changes,
            emits(DataSourceStatus(
                state: DataSourceState.valid, stateSince: DateTime(2))));

        await eventHandler!.handlePayload(context,
            Payload(type: PayloadType.full, updates: [flagEval('flagA', 1)]));

        expect(
            await eventHandler!.handlePayload(
                context,
                Payload(
                    type: PayloadType.full, updates: [flagEval('flagB', 2)]),
                environmentId: 'the-environment-id'),
            MessageStatus.messageHandled);

        expect(flagManager!.get('flagA'), isNull,
            reason: 'a full transfer replaces everything');
        expect(flagManager!.get('flagB')?.flag?.version, 2);
        expect(flagManager!.environmentId, 'the-environment-id');
      });

      test(
          'a partial payload applies updates without per-item version '
          'comparison and sets valid', () async {
        await eventHandler!.handlePayload(context,
            Payload(type: PayloadType.full, updates: [flagEval('flagA', 7)]));

        expect(
            await eventHandler!.handlePayload(
                context,
                Payload(
                    type: PayloadType.partial,
                    updates: [flagEval('flagA', 3, value: false)])),
            MessageStatus.messageHandled);

        final updated = flagManager!.get('flagA')!.flag!;
        expect(updated.version, 3,
            reason: 'FDv2 orders data at the payload level, so a lower '
                'envelope version still applies');
        expect(updated.detail.value, LDValue.ofBool(false));
      });

      test('a payload of none changes no data and sets valid', () async {
        await eventHandler!.handlePayload(context,
            Payload(type: PayloadType.full, updates: [flagEval('flagA', 1)]));

        expect(
            await eventHandler!.handlePayload(
                context, const Payload(type: PayloadType.none, updates: [])),
            MessageStatus.messageHandled);

        expect(flagManager!.get('flagA')?.flag?.version, 1);
      });

      test('invalid flag data sets an invalid data error', () async {
        expectLater(
            statusManager!.changes,
            emits(DataSourceStatus(
                lastError: DataSourceStatusErrorInfo(
                    kind: ErrorKind.invalidData,
                    message: 'FDv2 payload contained invalid data',
                    statusCode: null,
                    time: DateTime(2)),
                state: DataSourceState.initializing,
                stateSince: DateTime(1))));

        expect(
            await eventHandler!.handlePayload(
                context,
                Payload(type: PayloadType.full, updates: [
                  const Update(
                      kind: 'flag-eval',
                      key: 'bad',
                      version: 1,
                      object: {'trackEvents': 'not-a-bool'})
                ])),
            MessageStatus.invalidMessage);
      });
    });
  });
}
