import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

void main() {
  // In this test suite we want to compare JSON against an expected
  // base JSON. We don't deserialize from event contexts back into
  // regular contexts, so the approach taken is to compare against
  // the LDValue representation of the JSON. So we build the JSON,
  // decode it to an LDValue, and then compare that against a reference
  // LDValue.
  group('given single kind contexts', () {
    final basicContext = LDContextBuilder()
        .kind('organization', 'abc')
        .set('firstName', LDValue.ofString('Sue'))
        .set('bizzle', LDValue.ofString('def'))
        .set('dizzle', LDValue.ofString('hgi'))
        .build();

    final contextWithName = LDContextBuilder()
        .kind('organization', 'abc')
        .name('Name')
        .set('firstName', LDValue.ofString('Sue'))
        .set('bizzle', LDValue.ofString('def'))
        .set('dizzle', LDValue.ofString('hgi'))
        .build();

    final contextSpecifyingOwnPrivateAttr = LDContextBuilder()
        .kind('organization', 'abc')
        .set('firstName', LDValue.ofString('Sue'))
        .set('bizzle', LDValue.ofString('def'))
        .set('dizzle', LDValue.ofString('hgi'))
        .addPrivateAttributes(['dizzle', 'unused']).build();

    final anonymousContext = LDContextBuilder()
        .kind('organization', 'abc')
        .anonymous(true)
        .set('firstName', LDValue.ofString('Sue'))
        .set('bizzle', LDValue.ofString('def'))
        .set('dizzle', LDValue.ofString('hgi'))
        .build();

    final contextWithJsonAttribute = LDContextBuilder()
        .kind('organization', 'abc')
        .set(
            'address',
            LDValueObjectBuilder()
                .addString('city', 'FakeCity')
                .addString('street', '123 Fake St.')
                .build())
        .set(
            'l1',
            LDValueObjectBuilder()
                .addValue(
                    'l2',
                    LDValueObjectBuilder()
                        .addNum('num', 1)
                        .addBool('bool', false)
                        .build())
                .build())
        .build();

    final expectedBasicContext = LDValueObjectBuilder()
        .addString('kind', 'organization')
        .addString('key', 'abc')
        .addString('firstName', 'Sue')
        .addString('bizzle', 'def')
        .addString('dizzle', 'hgi')
        .build();

    final expectedContextWithName = LDValueObjectBuilder()
        .addString('kind', 'organization')
        .addString('key', 'abc')
        .addString('name', 'Name')
        .addString('firstName', 'Sue')
        .addString('bizzle', 'def')
        .addString('dizzle', 'hgi')
        .build();

    final expectedAnonymousContext = LDValueObjectBuilder()
        .addString('kind', 'organization')
        .addString('key', 'abc')
        .addBool('anonymous', true)
        .addString('firstName', 'Sue')
        .addString('bizzle', 'def')
        .addString('dizzle', 'hgi')
        .build();

    final expectedAnonymousContextWithFullRedaction = LDValueObjectBuilder()
        .addString('kind', 'organization')
        .addString('key', 'abc')
        .addBool('anonymous', true)
        .addValue(
            '_meta',
            LDValueObjectBuilder()
                .addValue(
                    'redactedAttributes',
                    LDValueArrayBuilder()
                        .addString('/firstName')
                        .addString('/bizzle')
                        .addString('/dizzle')
                        .build())
                .build())
        .build();

    group('when it is serializing as a context', () {
      final isEvent = false;
      test('it includes all the attributes and the non-redacted meta data form',
          () {
        final encoded =
            LDContextSerialization.toJson(basicContext, isEvent: isEvent);
        expect(LDValueSerialization.fromJson(encoded), expectedBasicContext);

        final encodedWithName =
            LDContextSerialization.toJson(contextWithName, isEvent: isEvent);
        expect(LDValueSerialization.fromJson(encodedWithName),
            expectedContextWithName);

        final anonymousEncoded =
            LDContextSerialization.toJson(anonymousContext, isEvent: isEvent);
        expect(LDValueSerialization.fromJson(anonymousEncoded),
            expectedAnonymousContext);

        final ownPrivateAttrsEncoded = LDContextSerialization.toJson(
            contextSpecifyingOwnPrivateAttr,
            isEvent: isEvent);
        expect(
            LDValueSerialization.fromJson(ownPrivateAttrsEncoded),
            LDValueObjectBuilder()
                .addString('kind', 'organization')
                .addString('key', 'abc')
                .addString('firstName', 'Sue')
                .addString('bizzle', 'def')
                .addString('dizzle', 'hgi')
                .addValue(
                    '_meta',
                    LDValueObjectBuilder()
                        .addValue(
                            'privateAttributes',
                            LDValueArrayBuilder()
                                .addString('dizzle')
                                .addString('unused')
                                .build())
                        .build())
                .build());
      });
    });

    group('when serializing for an event', () {
      final isEvent = true;

      test('it includes all the attributes by default', () {
        final encoded =
            LDContextSerialization.toJson(basicContext, isEvent: isEvent);
        expect(LDValueSerialization.fromJson(encoded), expectedBasicContext);

        final encodedWithName =
            LDContextSerialization.toJson(contextWithName, isEvent: isEvent);
        expect(LDValueSerialization.fromJson(encodedWithName),
            expectedContextWithName);

        final anonymousEncoded =
            LDContextSerialization.toJson(anonymousContext, isEvent: isEvent);
        expect(LDValueSerialization.fromJson(anonymousEncoded),
            expectedAnonymousContext);
      });

      test('redactAnonymous only affects anonymous contexts', () {
        final encoded = LDContextSerialization.toJson(basicContext,
            isEvent: isEvent, redactAnonymous: true);
        expect(LDValueSerialization.fromJson(encoded), expectedBasicContext);

        final encodedWithName = LDContextSerialization.toJson(contextWithName,
            isEvent: isEvent, redactAnonymous: true);
        expect(LDValueSerialization.fromJson(encodedWithName),
            expectedContextWithName);

        final anonymousEncoded = LDContextSerialization.toJson(anonymousContext,
            isEvent: isEvent, redactAnonymous: true);
        expect(LDValueSerialization.fromJson(anonymousEncoded),
            expectedAnonymousContextWithFullRedaction);
      });

      test(
          'it redacts all non-protected attributes when allAttributesPrivate = true',
          () {
        final encoded = LDContextSerialization.toJson(basicContext,
            isEvent: isEvent, allAttributesPrivate: true);
        expect(
            LDValueSerialization.fromJson(encoded),
            LDValueObjectBuilder()
                .addString('kind', 'organization')
                .addString('key', 'abc')
                .addValue(
                    '_meta',
                    LDValueObjectBuilder()
                        .addValue(
                            'redactedAttributes',
                            LDValueArrayBuilder()
                                .addString('/firstName')
                                .addString('/bizzle')
                                .addString('/dizzle')
                                .build())
                        .build())
                .build());

        final anonymousEncoded = LDContextSerialization.toJson(anonymousContext,
            isEvent: isEvent, allAttributesPrivate: true);
        expect(
            LDValueSerialization.fromJson(anonymousEncoded),
            LDValueObjectBuilder()
                .addString('kind', 'organization')
                .addString('key', 'abc')
                .addBool('anonymous', true)
                .addValue(
                    '_meta',
                    LDValueObjectBuilder()
                        .addValue(
                            'redactedAttributes',
                            LDValueArrayBuilder()
                                .addString('/firstName')
                                .addString('/bizzle')
                                .addString('/dizzle')
                                .build())
                        .build())
                .build());
      });

      test('it redacts private attributes specified by the context', () {
        final encoded = LDContextSerialization.toJson(
            contextSpecifyingOwnPrivateAttr,
            isEvent: isEvent);
        expect(
            LDValueSerialization.fromJson(encoded),
            LDValueObjectBuilder()
                .addString('kind', 'organization')
                .addString('key', 'abc')
                .addString('firstName', 'Sue')
                .addString('bizzle', 'def')
                .addValue(
                    '_meta',
                    LDValueObjectBuilder()
                        .addValue('redactedAttributes',
                            LDValueArrayBuilder().addString('dizzle').build())
                        .build())
                .build());
      });

      test('it redacts individual globally specified attributes', () {
        final encoded = LDContextSerialization.toJson(
            contextSpecifyingOwnPrivateAttr,
            isEvent: isEvent,
            globalPrivateAttributes: {AttributeReference('firstName')});
        expect(
            LDValueSerialization.fromJson(encoded),
            LDValueObjectBuilder()
                .addString('kind', 'organization')
                .addString('key', 'abc')
                .addString('bizzle', 'def')
                .addValue(
                    '_meta',
                    LDValueObjectBuilder()
                        .addValue(
                            'redactedAttributes',
                            LDValueArrayBuilder()
                                .addString('firstName')
                                .addString('dizzle')
                                .build())
                        .build())
                .build());
      });

      test('it can redact a partial json attribute', () {
        final encoded = LDContextSerialization.toJson(contextWithJsonAttribute,
            isEvent: isEvent,
            globalPrivateAttributes: {
              AttributeReference('/address/street'),
              AttributeReference('/l1/l2/bool')
            });
        expect(
            LDValueSerialization.fromJson(encoded),
            LDValueObjectBuilder()
                .addString('kind', 'organization')
                .addString('key', 'abc')
                .addValue(
                    'address',
                    LDValueObjectBuilder()
                        .addString('city', 'FakeCity')
                        .build())
                .addValue(
                    'l1',
                    LDValueObjectBuilder()
                        .addValue('l2',
                            LDValueObjectBuilder().addNum('num', 1).build())
                        .build())
                .addValue(
                    '_meta',
                    LDValueObjectBuilder()
                        .addValue(
                            'redactedAttributes',
                            LDValueArrayBuilder()
                                .addString('/address/street')
                                .addString('/l1/l2/bool')
                                .build())
                        .build())
                .build());
      });
    });
  });

  group('given a multi-kind context', () {
    final orgAndUserContext = LDContextBuilder()
        .kind('organization', 'LD')
        .anonymous(true)
        .set('rocks', LDValue.ofBool(true))
        .name('name')
        .set('department',
            LDValueObjectBuilder().addString('name', 'sdk').build())
        .kind('user', 'abc')
        .name('alphabet')
        .setPrivate(
            'letters',
            LDValueArrayBuilder()
                .addString('a')
                .addString('b')
                .addString('c')
                .build())
        .set('order', LDValue.ofNum(3))
        .set(
            'object',
            LDValueObjectBuilder()
                .addString('a', 'a')
                .addString('b', 'b')
                .build())
        .addPrivateAttributes(['/object/b']).build();

    group('when serialized as events', () {
      final isEvent = true;

      test(
          'it should remove attribute from all contexts when all attributes are private',
          () {
        final encoded = LDContextSerialization.toJson(orgAndUserContext,
            isEvent: isEvent, allAttributesPrivate: true);

        expect(
            LDValueSerialization.fromJson(encoded),
            LDValueObjectBuilder()
                .addString('kind', 'multi')
                .addValue(
                    'organization',
                    LDValueObjectBuilder()
                        .addString('key', 'LD')
                        .addBool('anonymous', true)
                        .addValue(
                            '_meta',
                            LDValueObjectBuilder()
                                .addValue(
                                    'redactedAttributes',
                                    LDValueArrayBuilder()
                                        .addString('/name')
                                        .addString('/rocks')
                                        .addString('/department')
                                        .build())
                                .build())
                        .build())
                .addValue(
                    'user',
                    LDValueObjectBuilder()
                        .addString('key', 'abc')
                        .addValue(
                            '_meta',
                            LDValueObjectBuilder()
                                .addValue(
                                    'redactedAttributes',
                                    LDValueArrayBuilder()
                                        .addString('/name')
                                        .addString('/letters')
                                        .addString('/order')
                                        .addString('/object')
                                        .build())
                                .build())
                        .build())
                .build());
      });

      test('it should apply private attributes from a context to that context',
          () {
        final encoded =
            LDContextSerialization.toJson(orgAndUserContext, isEvent: isEvent);

        expect(
            LDValueSerialization.fromJson(encoded),
            LDValueObjectBuilder()
                .addString('kind', 'multi')
                .addValue(
                    'organization',
                    LDValueObjectBuilder()
                        .addString('key', 'LD')
                        .addBool('rocks', true)
                        .addBool('anonymous', true)
                        .addString('name', 'name')
                        .addValue(
                            'department',
                            LDValueObjectBuilder()
                                .addString('name', 'sdk')
                                .build())
                        .build())
                .addValue(
                    'user',
                    LDValueObjectBuilder()
                        .addString('key', 'abc')
                        .addValue('object',
                            LDValueObjectBuilder().addString('a', 'a').build())
                        .addNum('order', 3.0)
                        .addString('name', 'alphabet')
                        .addValue(
                            '_meta',
                            LDValueObjectBuilder()
                                .addValue(
                                    'redactedAttributes',
                                    LDValueArrayBuilder()
                                        .addString('letters')
                                        .addString('/object/b')
                                        .build())
                                .build())
                        .build())
                .build());
      });

      test('it should only redact anonymous attributes from anonymous contexts',
          () {
        final encoded = LDContextSerialization.toJson(orgAndUserContext,
            isEvent: isEvent, redactAnonymous: true);

        expect(
            LDValueSerialization.fromJson(encoded),
            LDValueObjectBuilder()
                .addString('kind', 'multi')
                .addValue(
                    'organization',
                    LDValueObjectBuilder()
                        .addString('key', 'LD')
                        .addBool('anonymous', true)
                        .addValue(
                            '_meta',
                            LDValueObjectBuilder()
                                .addValue(
                                    'redactedAttributes',
                                    LDValueArrayBuilder()
                                        .addString('/name')
                                        .addString('/rocks')
                                        .addString('/department')
                                        .build())
                                .build())
                        .build())
                .addValue(
                    'user',
                    LDValueObjectBuilder()
                        .addString('key', 'abc')
                        .addValue('object',
                            LDValueObjectBuilder().addString('a', 'a').build())
                        .addNum('order', 3.0)
                        .addString('name', 'alphabet')
                        .addValue(
                            '_meta',
                            LDValueObjectBuilder()
                                .addValue(
                                    'redactedAttributes',
                                    LDValueArrayBuilder()
                                        .addString('letters')
                                        .addString('/object/b')
                                        .build())
                                .build())
                        .build())
                .build());
      });

      test('it should apply global private attributes to all contexts', () {
        final encoded = LDContextSerialization.toJson(orgAndUserContext,
            isEvent: isEvent,
            globalPrivateAttributes: {AttributeReference('name')});

        expect(
            LDValueSerialization.fromJson(encoded),
            LDValueObjectBuilder()
                .addString('kind', 'multi')
                .addValue(
                    'organization',
                    LDValueObjectBuilder()
                        .addString('key', 'LD')
                        .addBool('rocks', true)
                        .addBool('anonymous', true)
                        .addValue(
                            'department',
                            LDValueObjectBuilder()
                                .addString('name', 'sdk')
                                .build())
                        .addValue(
                            '_meta',
                            LDValueObjectBuilder()
                                .addValue(
                                    'redactedAttributes',
                                    LDValueArrayBuilder()
                                        .addString('name')
                                        .build())
                                .build())
                        .build())
                .addValue(
                    'user',
                    LDValueObjectBuilder()
                        .addString('key', 'abc')
                        .addValue('object',
                            LDValueObjectBuilder().addString('a', 'a').build())
                        .addNum('order', 3.0)
                        .addValue(
                            '_meta',
                            LDValueObjectBuilder()
                                .addValue(
                                    'redactedAttributes',
                                    LDValueArrayBuilder()
                                        .addString('name')
                                        .addString('letters')
                                        .addString('/object/b')
                                        .build())
                                .build())
                        .build())
                .build());
      });
    });
  });
}
