import 'package:launchdarkly_dart_client/ld_client.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_dart_client/src/flag_manager/flag_manager.dart';
import 'package:test/test.dart';

void main() {
  final logger = LDLogger();

  group('given data source event handler', () {
    DataSourceEventHandler? eventHandler;
    DataSourceStatusManager? statusManager;
    FlagManager? flagManager;

    setUp(() {
      flagManager =
          FlagManager(sdkKey: 'the-key', maxCachedContexts: 4, logger: logger);
      var time = 0;
      statusManager = DataSourceStatusManager(stamper: () {
        time++;
        return DateTime(time);
      });
      final context = LDContextBuilder().kind('user', 'user-key').build();
      eventHandler = DataSourceEventHandler(
          context: context,
          flagManager: flagManager!,
          statusManager: statusManager!, logger: logger);
    });

    test('it handles a put message without reasons', () {
      expectLater(
          statusManager!.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(2))));

      expectLater(flagManager!.changes,
          emits(FlagsChangedEvent(keys: ['HasBob', 'killswitch'])));

      eventHandler!.handleMessage(
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

    test('it can handle bad json', () {
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
          'put', '{"HasBob":{"ve#%()#*()*{"kind":"FALLTHROUGH"}}}');
    });

    test('it can handle an invalid, but well formed, payload', () {
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

      eventHandler!.handleMessage(
          'put', '{"HasBob":17}');
    });
  });
}
