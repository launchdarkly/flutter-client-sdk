final class OsInfo {
  final String? family;
  final String? name;
  final String? version;

  const OsInfo({this.family, this.name, this.version});

  @override
  String toString() {
    return 'OsInfo{family: $family, name: $name, version:'
        ' $version}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsInfo &&
          family == other.family &&
          name == other.name &&
          version == other.version;

  @override
  int get hashCode => family.hashCode ^ name.hashCode ^ version.hashCode;
}
