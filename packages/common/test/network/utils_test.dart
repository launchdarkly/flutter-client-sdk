import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:test/test.dart';

void main() {
  test('it joins URLs with a forward slash', () {
    expect(appendPath('this', '/that'), 'this/that');
  });

  test('it trims a trailing slash on a base URL', () {
    expect(appendPath('this', '/that'), 'this/that');
  });

  group('given globally recoverable errors', () {
    for (var status in [300, 400, 408, 429, 500]) {
      test('it reports the status is recoverable: $status', () {
        expect(isHttpGloballyRecoverable(status), isTrue);
      });
    }
  });

  group('given locally recoverable errors', () {
    for (var status in [300, 400, 408, 413, 429, 500]) {
      test('it reports the status is recoverable: $status', () {
        expect(isHttpLocallyRecoverable(status), isTrue);
      });
    }
  });

  group('given non-recoverable errors', () {
    for (var status in [401, 404, 499]) {
      test('it reports the status is not recoverable: $status', () {
        expect(isHttpGloballyRecoverable(status), isFalse);
      });
    }
  });
}
