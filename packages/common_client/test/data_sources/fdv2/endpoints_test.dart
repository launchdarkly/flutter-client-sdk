import 'package:launchdarkly_common_client/src/data_sources/fdv2/endpoints.dart';
import 'package:test/test.dart';

void main() {
  group('FDv2Endpoints', () {
    test('polling path is the FDv2 polling endpoint', () {
      expect(FDv2Endpoints.polling, equals('/sdk/poll/eval'));
    });

    test('streaming path is the FDv2 streaming endpoint', () {
      expect(FDv2Endpoints.streaming, equals('/sdk/stream/eval'));
    });

    test('pollingGet appends the encoded context', () {
      expect(
        FDv2Endpoints.pollingGet('eyJrZXkiOiJ0ZXN0In0='),
        equals('/sdk/poll/eval/eyJrZXkiOiJ0ZXN0In0='),
      );
    });

    test('streamingGet appends the encoded context', () {
      expect(
        FDv2Endpoints.streamingGet('eyJrZXkiOiJ0ZXN0In0='),
        equals('/sdk/stream/eval/eyJrZXkiOiJ0ZXN0In0='),
      );
    });
  });
}
