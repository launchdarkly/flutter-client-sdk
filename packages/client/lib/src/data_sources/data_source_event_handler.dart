import 'dart:convert';

import 'package:launchdarkly_dart_common/ld_common.dart';

import '../flag_manager/flag_manager.dart';
import '../item_descriptor.dart';
import 'data_source_status.dart';
import 'data_source_status_manager.dart';

enum MessageStatus { messageHandled, invalidMessage, unhandledVerb }

/// Represents patch JSON from the LaunchDarkly service.
final class PatchData {
  final String key;
  final LDEvaluationResult flag;

  PatchData(this.key, this.flag);
}

/// Represents delete JSON from the LaunchDarkly service.
final class DeleteData {
  final String key;
  num version;

  DeleteData(this.key, this.version);
}

/// The put data doesn't have a representation here because it is a map of
/// evaluation results.

final class DataSourceEventHandler {
  final FlagManager _flagManager;
  final DataSourceStatusManager _statusManager;
  final LDContext _context;
  final LDLogger _logger;

  Future<MessageStatus> handleMessage(String type, String data) async {
    switch (type) {
      case 'put':
        {
          try {
            final parsed = jsonDecode(data);
            return _processPut(parsed);
          } catch (err) {
            _logger.error('put message contained invalid json: $err');
            _statusManager.setErrorByKind(
                ErrorKind.invalidData, 'Could not parse PUT message');
            return MessageStatus.invalidMessage;
          }
        }
      case 'patch':
        {
          // TODO: Implement. Implement patch deserialization as well.
          return MessageStatus.unhandledVerb;
        }
      case 'delete':
        {
          // TODO: Implement. Implement delete deserialization as well.
          return MessageStatus.unhandledVerb;
        }
      default:
        {
          return MessageStatus.unhandledVerb;
        }
    }
  }

  Future<MessageStatus> _processPut(parsed) async {
    try {
      final putData = LDEvaluationResultsSerialization.fromJson(parsed).map(
          (key, value) => MapEntry(
              key, ItemDescriptor(version: value.version, flag: value)));
      await _flagManager.init(_context, putData);
      _statusManager.setValid();
      return MessageStatus.messageHandled;
    } catch (err) {
      _logger.error('put message contained an invalid payload: $err');
      _statusManager.setErrorByKind(
          ErrorKind.invalidData, 'PUT message contained invalid data');
      return MessageStatus.invalidMessage;
    }
  }

  DataSourceEventHandler(
      {required LDContext context,
      required FlagManager flagManager,
      required DataSourceStatusManager statusManager,
      required LDLogger logger})
      : _context = context,
        _flagManager = flagManager,
        _statusManager = statusManager,
        _logger = logger;
}
