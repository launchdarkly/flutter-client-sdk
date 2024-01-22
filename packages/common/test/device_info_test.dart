import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

void main() {
  test('equivalent device info objects are equal', (){
    final a = DeviceInfo(model: '9000', manufacturer: 'meme');
    final b = DeviceInfo(model: '9000', manufacturer: 'meme');

    expect(a, b);
  });

  test('non-equivalent device info objects are not equal', (){
    final a = DeviceInfo(model: '9001', manufacturer: 'meme');
    final b = DeviceInfo(model: '9000', manufacturer: 'meme');

    expect(a, isNot(b));
  });

  test('equivalent device info objects have equal hash codes', () {
    final a = DeviceInfo(model: '9000', manufacturer: 'meme');
    final b = DeviceInfo(model: '9000', manufacturer: 'meme');

    expect(a.hashCode, b.hashCode);
  });

  test('non-equivalent device info objects do not have equal hash codes', (){
    final a = DeviceInfo(model: '9001', manufacturer: 'meme');
    final b = DeviceInfo(model: '9000', manufacturer: 'meme');

    expect(a.hashCode, isNot(b.hashCode));
  });

  test('it produces the expected string', () {
    final a = DeviceInfo(model: '9001', manufacturer: 'meme');
    expect(a.toString(), 'DeviceInfo{model: 9001, manufacturer: meme}');
  });
}
