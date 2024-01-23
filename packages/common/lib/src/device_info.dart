final class DeviceInfo {
  final String? model;
  final String? manufacturer;

  const DeviceInfo({this.model, this.manufacturer});

  @override
  String toString() {
    return 'DeviceInfo{model: $model, manufacturer: $manufacturer}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          model == other.model &&
          manufacturer == other.manufacturer;

  @override
  int get hashCode => model.hashCode ^ manufacturer.hashCode;
}
