import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

void main() {
  test('context builder simple case', () {
    LDContextBuilder builder = LDContextBuilder();
    builder.kind('user', 'uuid').name('Todd');
    builder.kind('company', 'key').name('LaunchDarkly');
    LDContext context = builder.build();
    List<dynamic> output = context.toCodecValue();

    List<dynamic> expectedOutput = [
      {
        'kind': 'user',
        'key': 'uuid',
        'anonymous': false,
        'name': 'Todd',
        'custom': {},
        'privateAttributeNames': [],
      },
      {
        'kind': 'company',
        'key': 'key',
        'anonymous': false,
        'name': 'LaunchDarkly',
        'custom': {},
        'privateAttributeNames': [],
      }
    ];

    expect(output, equals(expectedOutput));
  });

  test('context builder anonymous', () {
    LDContextBuilder builder = LDContextBuilder();
    builder.kind('user', 'uuid').name('Todd');
    builder.kind('company', 'key').name('LaunchDarkly').anonymous(true);
    LDContext context = builder.build();
    List<dynamic> output = context.toCodecValue();

    List<dynamic> expectedOutput = [
      {
        'kind': 'user',
        'key': 'uuid',
        'anonymous': false,
        'name': 'Todd',
        'custom': {},
        'privateAttributeNames': Set(),
      },
      {
        'kind': 'company',
        'key': 'key',
        'anonymous': true,
        'name': 'LaunchDarkly',
        'custom': {},
        'privateAttributeNames': Set(),
      }
    ];

    expect(output, equals(expectedOutput));
  });

  test('context builder with custom type', () {
    LDContextBuilder builder = LDContextBuilder();
    builder.kind('user', 'uuid').name('Todd').set('level1', LDValue.buildObject().addValue('level2', LDValue.buildObject().addNum('aNumber', 7).build()).build());
    builder.kind('company', 'key').name('LaunchDarkly');
    LDContext context = builder.build();
    List<dynamic> output = context.toCodecValue();

    List<dynamic> expectedOutput = [
      {
        'kind': 'user',
        'key': 'uuid',
        'anonymous': false,
        'name': 'Todd',
        'custom': {
          'level1' : {
            'level2': {
              'aNumber': 7,
            }
          }
        },
        'privateAttributeNames': Set(),
      },
      {
        'kind': 'company',
        'key': 'key',
        'anonymous': false,
        'name': 'LaunchDarkly',
        'custom': {},
        'privateAttributeNames': Set(),
      }
    ];

    expect(output, equals(expectedOutput));
  });
}
