class DefaultPollingPaths {
  String pollingGetPath(String credential, String context) {
    return '/msdk/evalx/contexts/$context';
  }

  String pollingReportPath(String credential, String context) {
    return '/msdk/evalx/contexts';
  }
}
