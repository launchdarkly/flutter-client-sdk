import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

class LDUserAttr {
  static List<LDUserAttr> builtInAttrs =
    [ LDUserAttr('ip', (b, v) { b.ip(v); }, (b, v) { b.privateIp(v); }, (u) { return u.ip; })
    , LDUserAttr('email', (b, v) { b.email(v); }, (b, v) { b.privateEmail(v); }, (u) { return u.email; })
    , LDUserAttr('name', (b, v) { b.name(v); }, (b, v) { b.privateName(v); }, (u) { return u.name; })
    , LDUserAttr('firstName', (b, v) { b.firstName(v); }, (b, v) { b.privateFirstName(v); }, (u) { return u.firstName; })
    , LDUserAttr('lastName', (b, v) { b.lastName(v); }, (b, v) { b.privateLastName(v); }, (u) { return u.lastName; })
    , LDUserAttr('avatar', (b, v) { b.avatar(v); }, (b, v) { b.privateAvatar(v); }, (u) { return u.avatar; })
    , LDUserAttr('country', (b, v) { b.country(v); }, (b, v) { b.privateCountry(v); }, (u) { return u.country; })];

  final String fieldName;
  final void Function(LDUserBuilder, String) setPublic;
  final void Function(LDUserBuilder, String) setPrivate;
  final String? Function(LDUser) getter;

  LDUserAttr(this.fieldName, this.setPublic, this.setPrivate, this.getter);
}

void main() {
  test('builder built-in attributes public', () {
    LDUser user = LDUserBuilder('user key')
        .anonymous(false)
        .ip('192.0.2.5')
        .email('test@example.com')
        .name('a b')
        .firstName('c')
        .lastName('d')
        .avatar('cat')
        .country('de')
        .build();
    expect(user.key, equals('user key'));
    expect(user.anonymous, isFalse);
    expect(user.ip, equals('192.0.2.5'));
    expect(user.email, equals('test@example.com'));
    expect(user.name, equals('a b'));
    expect(user.firstName, equals('c'));
    expect(user.lastName, equals('d'));
    expect(user.avatar, equals('cat'));
    expect(user.country, equals('de'));
    expect(user.custom, isNull);
    expect(user.privateAttributeNames, isNull);
  });

  test('builder private built-in attributes', () {
    LDUserAttr.builtInAttrs.forEach((attr) {
      LDUserBuilder builder = LDUserBuilder('user key');
      attr.setPrivate(builder, 'val');
      LDUser user = builder.build();
      expect(user.privateAttributeNames?.length, equals(1));
      expect(user.privateAttributeNames?[0], equals(attr.fieldName));
      expect(attr.getter(user), equals('val'));
    });
  });

  test('builder custom attrs', () {
    LDUser user = LDUserBuilder('user key')
        .custom('custom1', LDValue.ofNull())
        .custom('custom2', LDValue.ofBool(false))
        .privateCustom('custom3', LDValue.ofString('abc'))
        .build();
    expect(user.custom?['custom1'], same(LDValue.ofNull()));
    expect(user.custom?['custom2'], same(LDValue.ofBool(false)));
    expect(user.custom?['custom3'], equals(LDValue.ofString('abc')));
    expect(user.privateAttributeNames?.length, equals(1));
    expect(user.privateAttributeNames?[0], equals('custom3'));
  });
}
