// @dart=2.7
part of launchdarkly_flutter_client_sdk;

/// An [LDUser] contains the attributes of a user context.
///
/// The user attributes determine the flag values in combination with the configured flag rules, and can also be
/// used for metrics, experimentation, and data export. The only mandatory property is the [LDUser.key], which must
/// uniquely identify each user.
///
/// Besides the key, [LDUser] supports two types of optional attributes: built-in attributes (e.g. [LDUser.name]) and
/// custom attributes. See [LDUserBuilder] for how to set the attribute values.
///
/// For a more complete description of user attributes and how they can be referenced in feature flag rules, see the
/// reference guide on [setting user attributes](https://docs.launchdarkly.com/home/managing-users/user-attributes) and
/// [targeting users](https://docs.launchdarkly.com/home/managing-flags/targeting-users).
class LDUser {
  /// The user's key.
  final String key;
  /// Whether this user is anonymous.
  final bool anonymous;

  /// The user's secondary attribute.
  final String secondary;
  /// The user's ip attribute.
  final String ip;
  /// The user's email attribute.
  final String email;
  /// The user's name attribute.
  final String name;
  /// The user's firstName attribute.
  final String firstName;
  /// The user's lastName attribute.
  final String lastName;
  /// The user's avatar attribute.
  final String avatar;
  /// The user's country attribute.
  final String country;

  /// The user's custom attributes.
  ///
  /// Note this Map is unmodifiable. Instead construct a new [LDUser] instance with [LDUserBuilder].
  final Map<String, LDValue> custom;

  /// Which of the user's attributes are specified to be private.
  ///
  /// The values of private attributes are not included in events to prevent them being recorded by the service. Note
  /// that this List is unmodifiable. Instead construct a new [LDUser] instance with [LDUserBuilder].
  final List<String> privateAttributeNames;

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
        privateAttributeNames = builder._privateAttributeNames.isEmpty ? null : List.unmodifiable(builder._privateAttributeNames);

  Map<String, dynamic> _toCodecValue() {
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
    result['custom'] = custom?.map((key, value) => MapEntry(key, value.codecValue()));
    result['privateAttributeNames'] = privateAttributeNames;
    return result;
  }
}

/// A builder for constructing [LDUser] objects.
class LDUserBuilder {
  static const String _SECONDARY = "secondary";
  static const String _IP = "ip";
  static const String _EMAIL = "email";
  static const String _NAME = "name";
  static const String _FIRST_NAME = "firstName";
  static const String _LAST_NAME = "lastName";
  static const String _AVATAR = "avatar";
  static const String _COUNTRY = "country";

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

  Set<String> _privateAttributeNames = new Set();

  /// Creates a new builder with the specified user key.
  LDUserBuilder(String key) {
    this._key = key;
  }

  /// Sets whether the user is anonymous.
  LDUserBuilder anonymous(bool anonymous) {
    this._anonymous = anonymous;
    return this;
  }

  /// Sets the user's secondary attribute.
  LDUserBuilder secondary(String secondary) {
    this._secondary = secondary;
    return this;
  }

  /// Sets the user's secondary attribute, marking it as private.
  LDUserBuilder privateSecondary(String secondary) {
    _privateAttributeNames.add(_SECONDARY);
    return this.secondary(secondary);
  }

  /// Sets the user's ip attribute.
  LDUserBuilder ip(String ip) {
    this._ip = ip;
    return this;
  }

  /// Sets the user's ip attribute, marking it as private.
  LDUserBuilder privateIp(String ip) {
    _privateAttributeNames.add(_IP);
    return this.ip(ip);
  }

  /// Sets the user's email attribute.
  LDUserBuilder email(String email) {
    this._email = email;
    return this;
  }

  /// Sets the user's email attribute, marking it as private.
  LDUserBuilder privateEmail(String email) {
    _privateAttributeNames.add(_EMAIL);
    return this.email(email);
  }

  /// Sets the user's name attribute.
  LDUserBuilder name(String name) {
    this._name = name;
    return this;
  }

  /// Sets the user's name attribute marking it as private.
  LDUserBuilder privateName(String name) {
    _privateAttributeNames.add(_NAME);
    return this.name(name);
  }

  /// Sets the user's first name attribute.
  LDUserBuilder firstName(String firstName) {
    this._firstName = firstName;
    return this;
  }

  /// Sets the user's first name attribute, marking it as private.
  LDUserBuilder privateFirstName(String firstName) {
    _privateAttributeNames.add(_FIRST_NAME);
    return this.firstName(firstName);
  }

  /// Sets the user's last name attribute.
  LDUserBuilder lastName(String lastName) {
    this._lastName = lastName;
    return this;
  }

  /// Sets the user's last name attribute, marking it as private.
  LDUserBuilder privateLastName(String lastName) {
    _privateAttributeNames.add(_LAST_NAME);
    return this.lastName(lastName);
  }

  /// Sets the user's avatar attribute.
  LDUserBuilder avatar(String avatar) {
    this._avatar = avatar;
    return this;
  }

  /// Sets the user's avatar attribute, marking it as private.
  LDUserBuilder privateAvatar(String avatar) {
    _privateAttributeNames.add(_AVATAR);
    return this.avatar(avatar);
  }

  /// Sets the user's country.
  LDUserBuilder country(String country) {
    this._country = country;
    return this;
  }

  /// Sets the user's country, marking it as private.
  LDUserBuilder privateCountry(String country) {
    _privateAttributeNames.add(_COUNTRY);
    return this.country(country);
  }

  /// Adds a new custom attribute to the user.
  ///
  /// [LDValue] is used to allow complex types, for example:
  /// ```
  /// LDUserBuilder('<USER_KEY>')
  ///   .privateCustom('my-custom-string', LDValue.ofString('str-value'))
  ///   .custom('my-custom-array', LDValue.buildArray().addNum(1).addNum(2).build())
  ///   .build();
  /// ```
  LDUserBuilder custom(String name, LDValue value) {
    this._custom[name] = value;
    return this;
  }

  /// Adds a new custom attribute to the user, marking it as private.
  LDUserBuilder privateCustom(String name, LDValue value) {
    _privateAttributeNames.add(name);
    return this.custom(name, value);
  }

  /// Constructs an [LDUser] instance from the values currently in the builder.
  LDUser build() {
    return LDUser._builder(this);
  }
}
