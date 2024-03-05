import '../ld_value.dart';

/// On a major version change removing LDValueSerialization, and directly using
/// fromDynamic and toDynamic, should be considered.

final class LDValueSerialization {
  static LDValue fromJson(dynamic json) {
    return LDValue.ofDynamic(json);
  }

  static dynamic toJson(LDValue value) {
    return value.toDynamic();
  }
}
