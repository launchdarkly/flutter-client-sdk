part of launchdarkly_flutter_client_sdk;

class LDUser {
  String key;
  //String secondary;
  bool anonymous;

  String ip;
  String email;
  String name;
  String firstName;
  String lastName;
  String avatar;
  String country;

  // custom TODO

  Set<String> privateAttributeNames;

  LDUser._builder(LDUserBuilder builder) :
        key = builder._key,
        anonymous = builder._anonymous,
        ip = builder._ip,
        email = builder._email,
        name = builder._name,
        firstName = builder._firstName,
        lastName = builder._lastName,
        avatar = builder._avatar,
        country = builder._country,
        privateAttributeNames = builder._privateAttributeNames;

  Map<String, dynamic> _toMap() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['key'] = key;
    result['anonymous'] = anonymous;
    result['ip'] = ip;
    result['email'] = email;
    result['name'] = name;
    result['firstName'] = firstName;
    result['lastName'] = lastName;
    result['avatar'] = avatar;
    result['country'] = country;
    result['privateAttributeNames'] = privateAttributeNames == null ? null : privateAttributeNames.toList(growable: false);
    return result;
  }
}

class LDUserBuilder {
  final String IP = "ip";
  final String COUNTRY = "country";
  final String SECONDARY = "secondary";
  final String FIRST_NAME = "firstName";
  final String LAST_NAME = "lastName";
  final String EMAIL = "email";
  final String NAME = "name";
  final String AVATAR = "avatar";

  String _key;
  //String secondary;
  bool _anonymous;

  String _ip;
  String _email;
  String _name;
  String _firstName;
  String _lastName;
  String _avatar;
  String _country;

  // custom TODO

  Set<String> _privateAttributeNames;

  LDUserBuilder(String key) {
    this._key = key;
  }

  LDUserBuilder ip(String ip) {
    this._ip = ip;
    return this;
  }

  LDUserBuilder privateIp(String ip) {
    _privateAttributeNames.add(IP);
    return this.ip(ip);
  }

  LDUserBuilder email(String email) {
    this._email = email;
    return this;
  }

  LDUserBuilder privateEmail(String email) {
    _privateAttributeNames.add(EMAIL);
    return this.email(email);
  }

  LDUserBuilder name(String name) {
    this._name = name;
    return this;
  }

  LDUserBuilder privateName(String name) {
    _privateAttributeNames.add(NAME);
    return this.name(name);
  }

  LDUserBuilder firstName(String firstName) {
    this._firstName = firstName;
    return this;
  }

  LDUserBuilder privateFirstName(String firstName) {
    _privateAttributeNames.add(FIRST_NAME);
    return this.firstName(firstName);
  }

  LDUserBuilder lastName(String lastName) {
    this._lastName = lastName;
    return this;
  }

  LDUserBuilder privateLastName(String lastName) {
    _privateAttributeNames.add(LAST_NAME);
    return this.lastName(lastName);
  }

  LDUserBuilder avatar(String avatar) {
    this._avatar = avatar;
    return this;
  }

  LDUserBuilder privateAvatar(String avatar) {
    _privateAttributeNames.add(AVATAR);
    return this.avatar(avatar);
  }

  LDUserBuilder country(String country) {
    this._country = country;
    return this;
  }

  LDUserBuilder privateCountry(String country) {
    _privateAttributeNames.add(COUNTRY);
    return this.country(country);
  }

  LDUser build() {
    return LDUser._builder(this);
  }
}