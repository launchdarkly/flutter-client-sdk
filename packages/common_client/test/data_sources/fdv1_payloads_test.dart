import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv1_payloads.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

void main() {
  final logger = LDLogger();

  final parsers = {
    'PUT': (String data) => parsePut(data, logger),
    'PATCH': (String data) => parsePatch(data, logger),
    'DELETE': (String data) => parseDelete(data, logger),
  };

  for (final MapEntry(key: type, value: parse) in parsers.entries) {
    test('a $type message that is not JSON is reported as unparsable', () {
      // Parse a payload that is not JSON.
      final event = parse('{"HasBob":{"ve#%()#*()*{"kind":"FALLTHROUGH"}}}');
      // The result reports invalid data.
      expect(
          event,
          isA<StatusEvent>()
              .having((e) => e.kind, 'kind', ErrorKind.invalidData)
              .having((e) => e.message, 'message',
                  'Could not parse $type message'));
    });

    test('a $type message with the wrong shape is reported as invalid', () {
      // Parse JSON that is not a flag payload.
      final event = parse('{"HasBob":17}');
      // The result reports invalid data.
      expect(
          event,
          isA<StatusEvent>()
              .having((e) => e.kind, 'kind', ErrorKind.invalidData)
              .having((e) => e.message, 'message',
                  '$type message contained invalid data'));
    });
  }
}
