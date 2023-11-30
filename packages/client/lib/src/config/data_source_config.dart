
import 'defaults/default_config.dart';

sealed class DataSourceConfig {
  /// Include evaluation reasons.
  final bool withReasons;

  /// The data source will attempt to use the reporting method if possible.
  ///
  /// For streaming requests on the web platform report is not supported.
  final bool useReport;

  final String credential;

  DataSourceConfig(
      {required this.withReasons,
      required this.useReport,
      required this.credential});
}

final _defaultPaths = DefaultConfig.pollingPaths;

final class PollingDataSourceConfig extends DataSourceConfig {
  /// The path to use for doing GET requests.
  String pollingGetPath(String context) {
    return _defaultPaths.pollingGetPath(credential, context);
  }

  /// The path to use for doing REPORT requests.
  String pollingReportPath(String context) {
    return _defaultPaths.pollingReportPath(credential, context);
  }

  /// The minimum polling interval.
  final Duration minPollingInterval = Duration(minutes: 5);

  /// The current polling interval, if less than min, then the min will be used.
  final Duration pollingInterval;

  PollingDataSourceConfig(
      {required this.pollingInterval,
      required super.withReasons,
      required super.useReport,
      required super.credential});
}
