import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../flag_manager/flag_manager.dart';
import '../item_descriptor.dart';
import 'data_source_status.dart';
import 'data_source_status_manager.dart';

enum MessageStatus { messageHandled, invalidMessage, unhandledVerb }

/// Represents patch JSON from the LaunchDarkly service.
final class _PatchData {
  final String key;
  final LDEvaluationResult flag;

  _PatchData(this.key, this.flag);
}

/// Represents delete JSON from the LaunchDarkly service.
final class _DeleteData {
  final String key;
  num version;

  _DeleteData(this.key, this.version);
}

final class _PatchDataSerialization {
  static _PatchData fromJson(dynamic json) {
    final key = json['key'] as String;
    final flag = LDEvaluationResultSerialization.fromJson(json);
    return _PatchData(key, flag);
  }
}

final class _DeleteDataSerialization {
  static _DeleteData fromJson(dynamic json) {
    final key = json['key'] as String;
    final version = json['version'] as num;
    return _DeleteData(key, version);
  }
}

/// The put data doesn't have a representation here because it is a map of
/// evaluation results.

final class DataSourceEventHandler {
  final FlagManager _flagManager;
  final DataSourceStatusManager _statusManager;
  final LDLogger _logger;

  Future<MessageStatus> handleMessage(
      LDContext context, String type, String data,
      {String? environmentId}) async {
    switch (type) {
      case 'put':
        {
          try {
            final parsed = jsonDecode(data);
            return _processPut(context, parsed, environmentId);
          } catch (err) {
            _logger.error('put message contained invalid json: $err');
            _statusManager.setErrorByKind(
                ErrorKind.invalidData, 'Could not parse PUT message');
            return MessageStatus.invalidMessage;
          }
        }
      case 'patch':
        {
          try {
            final parsed = jsonDecode(data);
            return _processPatch(context, parsed);
          } catch (err) {
            _logger.error('patch message contained invalid json: $err');
            _statusManager.setErrorByKind(
                ErrorKind.invalidData, 'Could not parse PATCH message');
            return MessageStatus.invalidMessage;
          }
        }
      case 'delete':
        {
          try {
            final parsed = jsonDecode(data);
            return _processDelete(context, parsed);
          } catch (err) {
            _logger.error('delete message contained invalid json: $err');
            _statusManager.setErrorByKind(
                ErrorKind.invalidData, 'Could not parse DELETE message');
            return MessageStatus.invalidMessage;
          }
        }
      default:
        {
          return MessageStatus.unhandledVerb;
        }
    }
  }

  Future<MessageStatus> _processPut(
      LDContext context, dynamic parsed, String? environmentId) async {
    try {
      final putData = LDEvaluationResultsSerialization.fromJson(parsed).map(
          (key, value) => MapEntry(
              key, ItemDescriptor(version: value.version, flag: value)));
      await _flagManager.init(context, putData, environmentId: environmentId);
      _statusManager.setValid();
      return MessageStatus.messageHandled;
    } catch (err) {
      _logger.error('put message contained an invalid payload: $err');
      _statusManager.setErrorByKind(
          ErrorKind.invalidData, 'PUT message contained invalid data');
      return MessageStatus.invalidMessage;
    }
  }

  Future<MessageStatus> _processPatch(LDContext context, dynamic parsed) async {
    try {
      final patchData = _PatchDataSerialization.fromJson(parsed);
      await _flagManager.upsert(
          context,
          patchData.key,
          ItemDescriptor(
              version: patchData.flag.version, flag: patchData.flag));
      return MessageStatus.messageHandled;
    } catch (err) {
      _logger.error('patch message contained an invalid payload: $err');
      _statusManager.setErrorByKind(
          ErrorKind.invalidData, 'PATCH message contained invalid data');
      return MessageStatus.invalidMessage;
    }
  }

  Future<MessageStatus> _processDelete(
      LDContext context, dynamic parsed) async {
    try {
      final deleteData = _DeleteDataSerialization.fromJson(parsed);
      await _flagManager.upsert(context, deleteData.key,
          ItemDescriptor(version: deleteData.version.toInt()));
      return MessageStatus.messageHandled;
    } catch (err) {
      _logger.error('delete message contained an invalid payload: $err');
      _statusManager.setErrorByKind(
          ErrorKind.invalidData, 'DELETE message contained invalid data');
      return MessageStatus.invalidMessage;
    }
  }

  DataSourceEventHandler(
      {required FlagManager flagManager,
      required DataSourceStatusManager statusManager,
      required LDLogger logger})
      : _flagManager = flagManager,
        _statusManager = statusManager,
        _logger = logger.subLogger('DataSourceEventHandler');
}
