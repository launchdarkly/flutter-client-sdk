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
      CompareCase(ConnectedEvent(), ConnectedEvent(), true),
      CompareCase(
          ConnectedEvent(),
          ConnectedEvent(headers: UnmodifiableMapView({'key': 'value'})),
          false),
      CompareCase(
          ConnectedEvent(headers: UnmodifiableMapView({'key': 'value'})),
          ConnectedEvent(),
          false),
      CompareCase(
          ConnectedEvent(headers: UnmodifiableMapView({'key': 'value'})),
          ConnectedEvent(headers: UnmodifiableMapView({'key': 'value'})),
          true),
      CompareCase(
          ConnectedEvent(headers: UnmodifiableMapView({'key': 'valueA'})),
          ConnectedEvent(headers: UnmodifiableMapView({'key': 'value'})),
          false),
      CompareCase(
          ConnectedEvent(
              headers:
                  UnmodifiableMapView({'key': 'value', 'second': 'value'})),
          ConnectedEvent(headers: UnmodifiableMapView({'key': 'value'})),
          false),
      CompareCase(
          ConnectedEvent(
              headers:
                  UnmodifiableMapView({'key': 'value', 'second': 'value'})),
          ConnectedEvent(
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
