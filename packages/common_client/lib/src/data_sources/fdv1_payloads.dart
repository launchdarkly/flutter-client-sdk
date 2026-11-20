import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'data_source.dart';
import 'data_source_status.dart';

/// Parses an FDv1 `put` payload into a [PutEvent], or into a [StatusEvent]
/// that says why the payload is unusable.
DataSourceEvent parsePut(String data, LDLogger logger,
        {String? environmentId}) =>
    _parse(
        'put',
        data,
        logger,
        (json) => PutEvent(LDEvaluationResultsSerialization.fromJson(json),
            environmentId: environmentId));

/// Parses an FDv1 `patch` payload into a [PatchEvent], or into a
/// [StatusEvent] that says why the payload is unusable.
DataSourceEvent parsePatch(String data, LDLogger logger) => _parse(
    'patch',
    data,
    logger,
    (json) => PatchEvent(
        json['key'] as String, LDEvaluationResultSerialization.fromJson(json)));

/// Parses an FDv1 `delete` payload into a [DeleteEvent], or into a
/// [StatusEvent] that says why the payload is unusable.
DataSourceEvent parseDelete(String data, LDLogger logger) => _parse(
    'delete',
    data,
    logger,
    (json) =>
        DeleteEvent(json['key'] as String, (json['version'] as num).toInt()));

DataSourceEvent _parse(String type, String data, LDLogger logger,
    DataSourceEvent Function(dynamic json) convert) {
  final dynamic json;
  try {
    json = jsonDecode(data);
  } catch (err) {
    logger.error('$type message contained invalid json: $err');
    return StatusEvent(ErrorKind.invalidData, null,
        'Could not parse ${type.toUpperCase()} message');
  }
  try {
    return convert(json);
  } catch (err) {
    logger.error('$type message contained an invalid payload: $err');
    return StatusEvent(ErrorKind.invalidData, null,
        '${type.toUpperCase()} message contained invalid data');
  }
}
