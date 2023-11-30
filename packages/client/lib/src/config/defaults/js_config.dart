class DefaultPollingPaths {

  String pollingGetPath(String credential, String context) {
    return '/sdk/evalx/$credential/contexts/$context';
  }

  String pollingReportPath(String credential, String context) {
    return '/sdk/evalx/$credential/context';
  }
}
