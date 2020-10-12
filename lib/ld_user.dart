part of launchdarkly_flutter_client_sdk;

part 'ld_value.dart';

class LDUser {
  final String key;
  final bool anonymous;

  final String secondary;
  final String ip;
  final String email;
  final String name;
  final String firstName;
  final String lastName;
  final String avatar;
  final String country;

  final Map<String, LDValue> custom;

  final Set<String> privateAttributeNames;

  LDUser._builder(LDUserBuilder builder) :
        key = builder._key,
        anonymous = builder._anonymous,
        secondary = builder._secondary,
        ip = builder._ip,
        email = builder._email,
        name = builder._name,
        firstName = builder._firstName,
        lastName = builder._lastName,
        avatar = builder._avatar,
        country = builder._country,
        custom = builder._custom.isEmpty ? null : Map.unmodifiable(builder._custom),
        privateAttributeNames = builder._privateAttributeNames;

  Map<String, dynamic> _toMap() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['key'] = key;
    result['anonymous'] = anonymous;
    result['secondary'] = secondary;
    result['ip'] = ip;
    result['email'] = email;
    result['name'] = name;
    result['firstName'] = firstName;
    result['lastName'] = lastName;
    result['avatar'] = avatar;
    result['country'] = country;
    result['custom'] = custom == null ? null : custom.map((key, value) => MapEntry(key, value._codecValue()));
    result['privateAttributeNames'] = privateAttributeNames == null ? null : privateAttributeNames.toList(growable: false);
    return result;
  }
}

class LDUserBuilder {
  static const String _IP = "ip";
  static const String _COUNTRY = "country";
  static const String _SECONDARY = "secondary";
  static const String _FIRST_NAME = "firstName";
  static const String _LAST_NAME = "lastName";
  static const String _EMAIL = "email";
  static const String _NAME = "name";
  static const String _AVATAR = "avatar";

  String _key;
  bool _anonymous;

  String _secondary;
  String _ip;
  String _email;
  String _name;
  String _firstName;
  String _lastName;
  String _avatar;
  String _country;

  Map<String, LDValue> _custom = new Map();

  Set<String> _privateAttributeNames;

  LDUserBuilder(String key) {
    this._key = key;
  }

  LDUserBuilder anonymous(bool anonymous) {
    this._anonymous = anonymous;
    return this;
  }

  LDUserBuilder secondary(String secondary) {
    this._secondary = secondary;
    return this;
  }

  LDUserBuilder privateSecondary(String secondary) {
    _privateAttributeNames.add(_SECONDARY);
    return this.secondary(secondary);
  }

  LDUserBuilder ip(String ip) {
    this._ip = ip;
    return this;
  }

  LDUserBuilder privateIp(String ip) {
    _privateAttributeNames.add(_IP);
    return this.ip(ip);
  }

  LDUserBuilder email(String email) {
    this._email = email;
    return this;
  }

  LDUserBuilder privateEmail(String email) {
    _privateAttributeNames.add(_EMAIL);
    return this.email(email);
  }

  LDUserBuilder name(String name) {
    this._name = name;
    return this;
  }

  LDUserBuilder privateName(String name) {
    _privateAttributeNames.add(_NAME);
    return this.name(name);
  }

  LDUserBuilder firstName(String firstName) {
    this._firstName = firstName;
    return this;
  }

  LDUserBuilder privateFirstName(String firstName) {
    _privateAttributeNames.add(_FIRST_NAME);
    return this.firstName(firstName);
  }

  LDUserBuilder lastName(String lastName) {
    this._lastName = lastName;
    return this;
  }

  LDUserBuilder privateLastName(String lastName) {
    _privateAttributeNames.add(_LAST_NAME);
    return this.lastName(lastName);
  }

  LDUserBuilder avatar(String avatar) {
    this._avatar = avatar;
    return this;
  }

  LDUserBuilder privateAvatar(String avatar) {
    _privateAttributeNames.add(_AVATAR);
    return this.avatar(avatar);
  }

  LDUserBuilder country(String country) {
    this._country = country;
    return this;
  }

  LDUserBuilder privateCountry(String country) {
    _privateAttributeNames.add(_COUNTRY);
    return this.country(country);
  }

  LDUserBuilder custom(String name, LDValue value) {
    this._custom[name] = value;
    return this;
  }

  LDUserBuilder privateCustom(String name, LDValue value) {
    _privateAttributeNames.add(name);
    return this.custom(name, value);
  }

  LDUser build() {
    return LDUser._builder(this);
  }
}
