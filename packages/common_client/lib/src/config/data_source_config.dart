import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'defaults/default_config.dart';

sealed class DataSourceConfigBase {
  /// Include evaluation reasons.
  final bool withReasons;

  /// The data source will attempt to use the reporting method if possible.
  ///
  /// For streaming requests on the web platform report is not supported.
  final bool useReport;

  DataSourceConfigBase({required this.withReasons, required this.useReport});
}

final class PollingDataSourceConfig extends DataSourceConfigBase {
  /// The path to use for doing GET requests.
  String pollingGetPath(String credential, String context) {
    return DefaultConfig.pollingPaths.pollingGetPath(credential, context);
  }

  /// The path to use for doing REPORT requests.
  String pollingReportPath(String credential, String context) {
    return DefaultConfig.pollingPaths.pollingReportPath(credential, context);
  }

  /// The current polling interval, if less than min, then the min will be used.
  final Duration pollingInterval;

  PollingDataSourceConfig(
      {Duration? pollingInterval, bool? withReasons, bool? useReport})
      : pollingInterval = durationWithMin(
            DefaultConfig.pollingConfig.defaultPollingInterval,
            pollingInterval,
            DefaultConfig.pollingConfig.minPollingInterval),
        super(
            withReasons: withReasons ??
                DefaultConfig.dataSourceConfig.defaultWithReasons,
            useReport:
                useReport ?? DefaultConfig.dataSourceConfig.defaultUseReport);
}

final class StreamingDataSourceConfig extends DataSourceConfigBase {
  /// The path to use for doing GET requests.
  String streamingGetPath(String credential, String context) {
    return DefaultConfig.streamingPaths.streamingGetPath(credential, context);
  }

  /// The path to use for doing REPORT requests.
  String streamingReportPath(String credential, String context) {
    return DefaultConfig.streamingPaths
        .streamingReportPath(credential, context);
  }

  StreamingDataSourceConfig({bool? withReasons, bool? useReport})
      : super(
            withReasons: withReasons ??
                DefaultConfig.dataSourceConfig.defaultWithReasons,
            useReport:
                useReport ?? DefaultConfig.dataSourceConfig.defaultUseReport);
}
