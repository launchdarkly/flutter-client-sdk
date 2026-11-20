import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../flag_manager/flag_manager.dart';
import '../item_descriptor.dart';
import 'data_source_status.dart';
import 'data_source_status_manager.dart';
import 'fdv2/payload.dart';

enum MessageStatus { messageHandled, invalidMessage }

final class DataSourceEventHandler {
  final FlagManager _flagManager;
  final DataSourceStatusManager _statusManager;
  final LDLogger _logger;

  /// Applies an FDv2 change set to the flag store.
  ///
  /// Full change sets replace the stored flags, partial change sets apply
  /// each update, and a change set of type none confirms the SDK is up to
  /// date without changing data.
  Future<MessageStatus> handlePayload(LDContext context, ChangeSet changeSet,
      {String? environmentId}) async {
    try {
      await _flagManager.applyChanges(
          context, changeSet.updates, changeSet.type,
          environmentId: environmentId);
      return MessageStatus.messageHandled;
    } catch (err) {
      _logger.error('Failed to apply an FDv2 change set: ${err.runtimeType}');
      _statusManager.setErrorByKind(
          ErrorKind.invalidData, 'Failed to apply an FDv2 change set');
      return MessageStatus.invalidMessage;
    }
  }

  /// Replaces every flag for [context] with [flags].
  Future<MessageStatus> handlePut(
      LDContext context, Map<String, LDEvaluationResult> flags,
      {String? environmentId}) async {
    try {
      final putData = flags.map((key, value) =>
          MapEntry(key, ItemDescriptor(version: value.version, flag: value)));
      await _flagManager.init(context, putData, environmentId: environmentId);
      _statusManager.setValid();
      return MessageStatus.messageHandled;
    } catch (err) {
      return _reject('put', err);
    }
  }

  /// Adds or replaces the flag [key] for [context].
  Future<MessageStatus> handlePatch(
      LDContext context, String key, LDEvaluationResult flag) async {
    try {
      await _flagManager.upsert(
          context, key, ItemDescriptor(version: flag.version, flag: flag));
      return MessageStatus.messageHandled;
    } catch (err) {
      return _reject('patch', err);
    }
  }

  /// Deletes the flag [key] for [context].
  Future<MessageStatus> handleDelete(
      LDContext context, String key, int version) async {
    try {
      await _flagManager.upsert(context, key, ItemDescriptor(version: version));
      return MessageStatus.messageHandled;
    } catch (err) {
      return _reject('delete', err);
    }
  }

  MessageStatus _reject(String type, Object err) {
    _logger.error('$type message contained an invalid payload: $err');
    _statusManager.setErrorByKind(ErrorKind.invalidData,
        '${type.toUpperCase()} message contained invalid data');
    return MessageStatus.invalidMessage;
  }

  DataSourceEventHandler(
      {required FlagManager flagManager,
      required DataSourceStatusManager statusManager,
      required LDLogger logger})
      : _flagManager = flagManager,
        _statusManager = statusManager,
        _logger = logger.subLogger('DataSourceEventHandler');
}
