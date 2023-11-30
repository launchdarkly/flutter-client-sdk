import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:test/test.dart';

void main() {
  test('can create a default instance', () {
    final properties = HttpProperties();
    expect(properties.connectTimeout, Duration(seconds: 10));
    expect(properties.readTimeout, Duration(seconds: 10));
    expect(properties.writeTimeout, Duration(seconds: 10));
    expect(properties.baseHeaders, isEmpty);
  });

  test('can set each property', () {
    final properties = HttpProperties(
        connectTimeout: Duration(seconds: 20),
        readTimeout: Duration(seconds: 30),
        writeTimeout: Duration(seconds: 40),
        baseHeaders: {'test': 'header'});
    expect(properties.connectTimeout, Duration(seconds: 20));
    expect(properties.readTimeout, Duration(seconds: 30));
    expect(properties.writeTimeout, Duration(seconds: 40));
    expect(properties.baseHeaders, hasLength(1));
    expect(properties.baseHeaders, containsPair('test', 'header'));
  });

  test('can create instance with additional headers', () {
    final properties = HttpProperties(baseHeaders: {'test': 'header'});
    final updated = properties.withHeaders({'added': 'value'});

    expect(updated.baseHeaders, hasLength(2));
    expect(updated.baseHeaders, containsPair('test', 'header'));
    expect(updated.baseHeaders, containsPair('added', 'value'));
  });

  test('cannot mutate headers', () {
    expect(() {
      final properties = HttpProperties();
      properties.baseHeaders['potato'] = 'fail';
    }, throwsUnsupportedError);
  });
}
