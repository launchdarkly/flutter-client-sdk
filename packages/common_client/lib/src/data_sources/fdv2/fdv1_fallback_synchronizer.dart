import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;

import '../../config/data_source_config.dart';
import '../../item_descriptor.dart';
import '../data_source.dart'
    show
        DataEvent,
        DataSourceEvent,
        InitializedEvent,
        PayloadEvent,
        StatusEvent;
import '../requestor.dart' as fdv1;
import 'entry_factories.dart' show SynchronizerFactory, mergeServiceEndpoints;
import 'mode_definition.dart';
import 'payload.dart';
import 'polling_synchronizer.dart';
import 'selector.dart';
import 'source.dart';
import 'source_factory_context.dart';
import 'source_result.dart';

/// Builds the FDv1 fallback synchronizer: an FDv1 poller whose responses are
/// translated into FDv2 change sets.
///
/// Engaged only when the server directs fallback (the `x-ld-fd-fallback`
/// response header, detected by the primary FDv2 sources). It is the terminal
/// tier and never re-asserts the fallback directive -- every result it emits
/// carries `fdv1Fallback: false`.
///
/// FDv1 has no delta protocol, so it polls with the context in the path and
/// each response is a complete flag set, translated to a `full` change set
/// with no selector.
SynchronizerFactory createFdv1FallbackSynchronizerFactory(
  Fdv1FallbackConfig config,
  SourceFactoryContext ctx,
) {
  final endpoints =
      mergeServiceEndpoints(ctx.serviceEndpoints, config.endpoints);
  final interval = config.pollInterval ?? ctx.defaultPollingInterval;
  final pollingConfig = PollingDataSourceConfig(
    useReport: false,
    withReasons: ctx.withReasons,
    pollingInterval: interval,
  );

  return SynchronizerFactory(
    create: (SelectorGetter selectorGetter) {
      final requestor = fdv1.Requestor(
        logger: ctx.logger,
        contextString: base64UrlEncode(utf8.encode(ctx.contextJson)),
        method: RequestMethod.get,
        httpProperties: ctx.httpProperties,
        credential: ctx.credential,
        endpoints: endpoints,
        dataSourceConfig: pollingConfig,
        httpClientFactory: ctx.httpClientFactory ?? _defaultHttpClientFactory,
      );
      return FDv2PollingSynchronizer(
        // FDv1 has no basis/selector, so the selector argument is ignored.
        poll: ({Selector basis = Selector.empty}) async =>
            _translate(await requestor.requestAllFlags()),
        selectorGetter: selectorGetter,
        interval: interval,
        logger: ctx.logger,
      );
    },
  );
}

HttpClient _defaultHttpClientFactory(HttpProperties httpProperties) =>
    HttpClient(httpProperties: httpProperties);

/// Translates an FDv1 polling result into an FDv2 source result. Results
/// always carry `fdv1Fallback: false` (the default), so the fallback tier can
/// never re-trigger fallback.
FDv2SourceResult _translate(DataSourceEvent? event) {
  switch (event) {
    case null:
      // 304 Not Modified: the SDK's data is confirmed current.
      return const ChangeSetResult(
        changeSet: ChangeSet(type: PayloadType.none, updates: {}),
        persist: false,
      );
    case DataEvent():
      try {
        final results =
            LDEvaluationResultsSerialization.fromJson(jsonDecode(event.data));
        final updates = results.map((key, value) =>
            MapEntry(key, ItemDescriptor(version: value.version, flag: value)));
        // FDv1 carries no selector; every poll is a complete snapshot.
        return ChangeSetResult(
          changeSet: ChangeSet(type: PayloadType.full, updates: updates),
          environmentId: event.environmentId,
          persist: true,
        );
      } catch (_) {
        return const StatusResult(
          state: SourceState.interrupted,
          message: 'Could not parse FDv1 fallback payload',
        );
      }
    case StatusEvent():
      return StatusResult(
        state: event.shutdown
            ? SourceState.terminalError
            : SourceState.interrupted,
        message: event.message,
        statusCode: event.statusCode?.toInt(),
      );
    case PayloadEvent():
    case InitializedEvent():
      // The FDv1 requestor only produces DataEvent / StatusEvent / null.
      return const StatusResult(
        state: SourceState.interrupted,
        message: 'Unexpected event from the FDv1 fallback poller',
      );
  }
}
