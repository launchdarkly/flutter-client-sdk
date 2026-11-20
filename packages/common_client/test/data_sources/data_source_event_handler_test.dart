import 'dart:convert';

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_common_client/src/item_descriptor.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

Map<String, LDEvaluationResult> _flags(String json) =>
    LDEvaluationResultsSerialization.fromJson(jsonDecode(json));

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

      eventHandler!.handlePut(
          context,
          _flags(
              '{"HasBob":{"version":11,"flagVersion":5,"value":false,"variation":1,'
              '"trackEvents":false},'
              '"killswitch":{"version":10,"flagVersion":4,"value":true,'
              '"variation":0,"trackEvents":false}'
              '}'));

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

      eventHandler!.handlePut(
          context,
          _flags(
              '{"HasBob":{"version":11,"flagVersion":5,"value":false,"variation":1,'
              '"trackEvents":false,"reason":{"kind":"FALLTHROUGH"}},'
              '"killswitch":{"version":10,"flagVersion":4,"value":true,'
              '"variation":0,"trackEvents":false,"reason":{"kind":"FALLTHROUGH"}}}'));

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

      eventHandler!.handlePut(
          context,
          _flags(
              '{"HasBob":{"version":11,"flagVersion":5,"value":false,"variation":1,'
              '"trackEvents":false}}'),
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

      eventHandler!.handlePut(
          context,
          _flags(
              '{"HasBob":{"version":11,"flagVersion":5,"value":false,"variation":1,'
              '"trackEvents":false}}'));

      final bob = flagManager!.get('HasBob')!.flag!;
      expect(bob.version, 11);
      expect(bob.detail.value, LDValue.ofBool(false));
      expect(bob.detail.variationIndex, 1);

      // Environment ID should be null when not provided
      expect(flagManager!.environmentId, null);
    });

    group('given a handler which has received a put', () {
      setUp(() async {
        await eventHandler!.handlePut(
            context,
            _flags(
                '{"my-boolean-flag":{"version":11,"flagVersion":5,"value":false,"variation":1,'
                '"trackEvents":false},'
                '"killswitch":{"version":10,"flagVersion":4,"value":true,'
                '"variation":0,"trackEvents":false}'
                '}'));
      });

      test('it handles a PATCH message without reasons', () async {
        expect(
            await eventHandler!.handlePatch(
                context,
                'my-boolean-flag',
                LDEvaluationResultSerialization.fromJson(jsonDecode(
                    '{"version": 681, "flagVersion": 53,'
                    ' "value": true, "variation": 1, "trackEvents": false}'))),
            MessageStatus.messageHandled);

        final updated = flagManager!.get('my-boolean-flag')!;
        expect(updated.version, 681);
        expect(updated.flag!.detail.value.booleanValue(), true);
      });

      test('it handles a PATCH message with reasons', () async {
        expect(
            await eventHandler!.handlePatch(
                context,
                'my-boolean-flag',
                LDEvaluationResultSerialization.fromJson(
                    jsonDecode('{"version":681,"flagVersion":56,'
                        '"value":true,"variation":0,"trackEvents":false,'
                        '"reason":{"kind":"FALLTHROUGH"}}'))),
            MessageStatus.messageHandled);

        final updated = flagManager!.get('my-boolean-flag')!;
        expect(updated.version, 681);
        expect(updated.flag!.detail.value.booleanValue(), true);
        expect(updated.flag!.detail.reason, LDEvaluationReason.fallthrough());
      });

      test('it handles a DELETE message', () async {
        expect(
            await eventHandler!.handleDelete(context, 'my-boolean-flag', 681),
            MessageStatus.messageHandled);

        final updated = flagManager!.get('my-boolean-flag')!;
        expect(updated.version, 681);
        expect(updated.flag, isNull);
      });
    });

    group('handlePayload', () {
      // The change set reaching handlePayload is already translated into
      // typed descriptors by the data source layer, so these build
      // descriptors directly. Translation-failure handling is covered at
      // the source layer (streaming/polling base tests).
      ItemDescriptor flagEval(int version, {bool value = true}) =>
          ItemDescriptor(
            version: version,
            flag: LDEvaluationResult(
              version: version,
              detail: LDEvaluationDetail(
                  LDValue.ofBool(value), 0, LDEvaluationReason.off()),
            ),
          );

      test('a full change set replaces the stored flags', () async {
        await eventHandler!.handlePayload(context,
            ChangeSet(type: PayloadType.full, updates: {'flagA': flagEval(1)}));

        expect(
            await eventHandler!.handlePayload(
                context,
                ChangeSet(
                    type: PayloadType.full, updates: {'flagB': flagEval(2)}),
                environmentId: 'the-environment-id'),
            MessageStatus.messageHandled);

        expect(flagManager!.get('flagA'), isNull,
            reason: 'a full transfer replaces everything');
        expect(flagManager!.get('flagB')?.flag?.version, 2);
        expect(flagManager!.environmentId, 'the-environment-id');
      });

      test(
          'a partial change set applies updates without per-item version '
          'comparison', () async {
        await eventHandler!.handlePayload(context,
            ChangeSet(type: PayloadType.full, updates: {'flagA': flagEval(7)}));

        expect(
            await eventHandler!.handlePayload(
                context,
                ChangeSet(
                    type: PayloadType.partial,
                    updates: {'flagA': flagEval(3, value: false)})),
            MessageStatus.messageHandled);

        final updated = flagManager!.get('flagA')!.flag!;
        expect(updated.version, 3,
            reason: 'FDv2 orders data at the payload level, so a lower '
                'envelope version still applies');
        expect(updated.detail.value, LDValue.ofBool(false));
      });

      test('a change set of none changes no data', () async {
        await eventHandler!.handlePayload(context,
            ChangeSet(type: PayloadType.full, updates: {'flagA': flagEval(1)}));

        expect(
            await eventHandler!.handlePayload(
                context, const ChangeSet(type: PayloadType.none, updates: {})),
            MessageStatus.messageHandled);

        expect(flagManager!.get('flagA')?.flag?.version, 1);
      });
    });
  });
}
