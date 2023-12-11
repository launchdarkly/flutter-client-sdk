import 'package:test/test.dart';
import 'package:launchdarkly_dart_common/ld_common.dart';

void main() {
  test('can get a canonical key for a user', () {
    // For a user kind the key has no special encoding.
    expect(LDContextBuilder().kind('user', 'user-key%:').build().canonicalKey,
        'user-key%:');
  });

  test('can get a canonical key for a single kind context', () {
    expect(
        LDContextBuilder()
            .kind('organization', 'org-key%:')
            .build()
            .canonicalKey,
        'organization:org-key%25%3A');
  });

  test('can get keys for a single kind context', () {
    expect(
        LDContextBuilder()
            .kind('organization', 'org-key%:')
            .build()
            .keys,
        <String, String>{'organization': 'org-key%:'});
  });

  test('can get a canonical key for a multi-kind context', () {
    // Should be sorted by kind and also the keys should be encoded.
    expect(
        LDContextBuilder()
            .kind('zoo', 'zoo-key:%')
            .kind('organization', 'org-key%:')
            .build()
            .canonicalKey,
        'organization:org-key%25%3A:zoo:zoo-key%3A%25');
  });

  test('can get a keys for a multi-kind context', () {
    // Should be sorted by kind and also the keys should be encoded.
    expect(
        LDContextBuilder()
            .kind('zoo', 'zoo-key:%')
            .kind('organization', 'org-key%:')
            .build()
            .keys,
        <String, String>{'zoo': 'zoo-key:%', 'organization': 'org-key%:'});
  });

  group('given invalid kinds', () {
    for (var kind in ['', 'kind', '#*%']) {
      test('invalid kinds produce invalid contexts', () {
        expect(LDContextBuilder().kind(kind, 'my-key').build().valid, false);
      });
    }
  });

  test('can get the canonical key for an invalid context', () {
    expect(LDContextBuilder().build().canonicalKey, '');
  });

  test('can change the key of a context during build', () {
    final context = LDContextBuilder()
        .kind('user', 'user-key')
        .kind('user', 'bob-key')
        .build();

    expect(context.valid, true);
    expect(context.get('user', AttributeReference('key')).stringValue(),
        'bob-key');
  });

  test('can set custom attributes', () {
    final context = LDContextBuilder()
        .kind('user', 'user-key')
        .set('customA', LDValue.ofNum(42))
        .build();

    expect(context.get('user', AttributeReference('customA')).intValue(), 42);
  });

  test('can get a nested attribute', () {
    final context = LDContextBuilder()
        .kind('org', 'org-key')
        .set('myJson', LDValue.buildObject().addBool('myBool', true).build())
        .build();

    expect(
        context.get('org', AttributeReference('/myJson/myBool')).booleanValue(),
        true);
  });

  test(
      'get LDValue.ofNull() addressing a top-level attribute that does not exist',
      () {
    final context = LDContextBuilder().kind('org', 'org-key').build();

    expect(context.get('org', AttributeReference('/myJson/myBool')),
        LDValue.ofNull());
  });

  test('get LDValue.ofNull() addressing a nested attribute that does not exist',
      () {
    final context = LDContextBuilder()
        .kind('org', 'org-key')
        .set('myJson',
            LDValue.buildObject().addString('myString', 'true').build())
        .build();

    expect(context.get('org', AttributeReference('/myJson/myBool')),
        LDValue.ofNull());
  });

  test('get LDValue.ofNull() for addressing a context kind that does not exist',
      () {
    final context = LDContextBuilder()
        .kind('org', 'org-key')
        .set('myJson', LDValue.buildObject().addBool('myBool', true).build())
        .build();

    expect(context.get('user', AttributeReference('/myJson/myBool')),
        LDValue.ofNull());
  });

  test('can get built-in attributes', () {
    final context = LDContextBuilder()
        .kind('org', 'org-key')
        .anonymous(true)
        .name('tater')
        .build();

    expect(
        context.get('org', AttributeReference('key')).stringValue(), 'org-key');

    expect(
        context.get('org', AttributeReference('name')).stringValue(), 'tater');

    expect(context.get('org', AttributeReference('anonymous')).booleanValue(),
        true);

    // This isn't used in practice for evaluation, because kind matches
    // are at the context level, and check if the context contains the
    // specified kind.
    expect(context.get('org', AttributeReference('kind')).stringValue(), 'org');
  });

  test('can set private attributes using setPrivate', () {
    final context = LDContextBuilder()
        .kind('org', 'org-key')
        .setPrivate('custom1', LDValue.ofString('test'))
        .setPrivate('/cus~tom/', LDValue.ofString('test'))
        .build();

    final attributes = context.attributesByKind['org'];
    expect(
        attributes?.privateAttributes.contains(AttributeReference('custom1')),
        true);

    expect(
        attributes?.privateAttributes
            .contains(AttributeReference('/~1cus~0tom~1')),
        true);
    expect(attributes?.privateAttributes.length, 2);
  });

  test('can add private attributes', () {
    final context = LDContextBuilder()
        .kind('franchise', 'org-key')
        // "/test" and "test" are dupes and "/test/" is invalid.
        .addPrivateAttributes(['/test', 'test', '/test/', '/bacon']).build();

    final attributes = context.attributesByKind['franchise'];
    expect(attributes?.privateAttributes.contains(AttributeReference('test')),
        true);

    expect(attributes?.privateAttributes.contains(AttributeReference('bacon')),
        true);
    expect(attributes?.privateAttributes.length, 2);
  });

  test('can get attributes by kind', () {
    final context = LDContextBuilder()
        .kind('zoo', 'zoo-key:%')
        .set('a', LDValue.ofString('b'))
        .kind('organization', 'org-key%:')
        .set('a', LDValue.ofNum(42))
        .build();

    expect(
        context.attributesByKind['zoo']?.customAttributes['a']?.stringValue(),
        'b');
    expect(
        context.attributesByKind['organization']?.customAttributes['a']
            ?.intValue(),
        42);
  });
}
