import 'environment_reporter.dart';

/// Creates an [EnvironmentReport] that returns data from the provided
/// config layer if available, otherwise falling back to the platform layer.
/// Note is is possible to get data for, say, application info from one layer
/// and then get device info from another layer.
class PrioritizedEnvReportBuilder {
  EnvironmentReporter _configLayer = ConcreteEnvReporter.ofNulls();
  EnvironmentReporter _platformLayer = ConcreteEnvReporter.ofNulls();

  PrioritizedEnvReportBuilder setConfigLayer(EnvironmentReporter config) {
    _configLayer = config;
    return this;
  }

  PrioritizedEnvReportBuilder setPlatformLayer(EnvironmentReporter platform) {
    _platformLayer = platform;
    return this;
  }

  Future<T?> _firstNonNull<T>(Iterable<Future<T?>> futures) async {
    for (var f in futures) {
      final v = await f;
      if (v != null) {
        return f;
      }
    }

    // if no futures can provide a value, return null
    return Future.value(null);
  }

  /// Build a complete environment report.
  Future<EnvironmentReport> build() async {
    // order of this list impacts behavior
    List<EnvironmentReporter> reporters = [_configLayer, _platformLayer];

    return EnvironmentReport(
        applicationInfo: await _firstNonNull(
            reporters.map((layer) => layer.applicationInfo)),
        osInfo: await _firstNonNull(reporters.map((layer) => layer.osInfo)),
        deviceInfo:
            await _firstNonNull(reporters.map((layer) => layer.deviceInfo)),
        locale: await _firstNonNull(reporters.map((layer) => layer.locale)));
  }
}
