import 'dart:collection';

import 'package:test/test.dart';
import 'package:launchdarkly_event_source_client/src/events.dart';

class CompareCase {
  final Event a;
  final Event b;
  final bool result;

  const CompareCase(this.a, this.b, this.result);

  @override
  String toString() {
    return '$a, $b, $result';
  }
}

void main() {
  group('given different connect messages', () {
    var cases = [
      CompareCase(OpenEvent(), OpenEvent(), true),
      CompareCase(
          OpenEvent(),
          OpenEvent(headers: UnmodifiableMapView({'key': 'value'})),
          false),
      CompareCase(
          OpenEvent(headers: UnmodifiableMapView({'key': 'value'})),
          OpenEvent(),
          false),
      CompareCase(
          OpenEvent(headers: UnmodifiableMapView({'key': 'value'})),
          OpenEvent(headers: UnmodifiableMapView({'key': 'value'})),
          true),
      CompareCase(
          OpenEvent(headers: UnmodifiableMapView({'key': 'valueA'})),
          OpenEvent(headers: UnmodifiableMapView({'key': 'value'})),
          false),
      CompareCase(
          OpenEvent(
              headers:
                  UnmodifiableMapView({'key': 'value', 'second': 'value'})),
          OpenEvent(headers: UnmodifiableMapView({'key': 'value'})),
          false),
      CompareCase(
          OpenEvent(
              headers:
                  UnmodifiableMapView({'key': 'value', 'second': 'value'})),
          OpenEvent(
              headers:
                  UnmodifiableMapView({'second': 'value', 'key': 'value'})),
          true),
    ];

    for (var testCase in cases) {
      test('Compare $testCase', () {
        expect(testCase.a == testCase.b, equals(testCase.result));
      });

      test('HashCode $testCase', () {
        var codeA = testCase.a.hashCode;
        var codeB = testCase.b.hashCode;
        if (testCase.result) {
          expect(codeA, equals(codeB));
        } else {
          expect(codeA, isNot(equals(codeB)));
        }
      });
    }
  });
}
