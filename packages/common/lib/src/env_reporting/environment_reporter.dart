import '../application_info.dart';
import '../os_info.dart';
import '../device_info.dart';

final class EnvironmentReport {
  ApplicationInfo? applicationInfo;
  OsInfo? osInfo;
  DeviceInfo? deviceInfo;
  String? locale;

  EnvironmentReport(
      {this.applicationInfo, this.osInfo, this.deviceInfo, this.locale});
}

/// An [EnvironmentReporter] is able to report various attributes
/// of the environment in which the application is running. If a property is null,
/// it means the reporter was unable to determine the value.
abstract interface class EnvironmentReporter {
  /// Returns the [ApplicationInfo] for the application environment.
  Future<ApplicationInfo?> get applicationInfo;

  /// Returns the [OsInfo] for the application environment.
  Future<OsInfo?> get osInfo;

  /// Returns the [DeviceInfo] for the application environment.
  Future<DeviceInfo?> get deviceInfo;

  /// Returns the locale for the application environment in the format languagecode2-country/regioncode2.
  Future<String?> get locale;
}

class ConcreteEnvReporter implements EnvironmentReporter {
  @override
  final Future<ApplicationInfo?> applicationInfo;
  @override
  final Future<OsInfo?> osInfo;
  @override
  final Future<DeviceInfo?> deviceInfo;
  @override
  final Future<String?> locale;

  ConcreteEnvReporter(
      {required this.applicationInfo, // uses required because the future is the required part
      required this.osInfo,
      required this.deviceInfo,
      required this.locale});

  ConcreteEnvReporter.ofNulls()
      : applicationInfo = Future.value(null),
        osInfo = Future.value(null),
        deviceInfo = Future.value(null),
        locale = Future.value(null);
}
