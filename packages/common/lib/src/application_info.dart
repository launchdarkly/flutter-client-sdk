/// Application metadata may be used by LaunchDarkly analytics or other product
/// features.
final class ApplicationInfo {
  String? applicationId;
  String? applicationName;
  String? applicationVersion;
  String? applicationVersionName;

  final validCharsRegex = RegExp(r'^[-a-zA-Z0-9._]+$', unicode: false);

  /// Creates an [ApplicationInfo].
  ///
  /// All provided fields can be specified as
  /// any string value as long as it only uses the following characters: ASCII
  /// letters, ASCII digits, space, period, hyphen, underscore. Spaces will
  /// be replaced with hyphens. A string containing any other characters will be
  /// ignored.
  ///
  /// [applicationId] is unique identifier representing the application where
  /// the LaunchDarkly SDK is running.
  ///
  /// Example: `timer-app`
  ///
  /// [applicationVersion] is a unique identifier representing the version of
  /// the application where the LaunchDarkly SDK is running.
  ///
  /// Example: `1.0.0` (standard version string) or `abcdef` (sha prefix)
  ///
  /// [applicationName] is a friendly name for your application and
  /// [applicationVersionName] is a friendly variation of the version.
  ///
  /// For example your [applicationId] maybe be `com.example.myapp` and the
  /// [applicationName] could be `MyApp`. The [applicationVersion] may be
  /// `10.1.54345784-7` and the [applicationVersionName] could be `10`.
  ApplicationInfo(
      {required String applicationId,
      String? applicationName,
      String? applicationVersion,
      String? applicationVersionName}) {
    this.applicationId = _sanitizeAndValidate(applicationId);
    this.applicationName = _sanitizeAndValidate(applicationName);
    this.applicationVersion = _sanitizeAndValidate(applicationVersion);
    this.applicationVersionName = _sanitizeAndValidate(applicationVersionName);
  }

  /// Replaces some prohibited whitespace with substitutes and then validates
  /// that the value.  If the value is valid, same value is returned.  If
  /// value is invalid or null, null is returned.
  String? _sanitizeAndValidate(String? value) {
    final sanitized = value?.replaceAll(' ', '-');
    if (sanitized != null &&
        sanitized.length <= 64 &&
        validCharsRegex.hasMatch(sanitized)) {
      return sanitized;
    } else {
      return null;
    }
  }

  @override
  String toString() {
    return 'ApplicationInfo{applicationId: $applicationId, applicationName: $applicationName, applicationVersion:'
        ' $applicationVersion, applicationVersionName: $applicationVersionName}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationInfo &&
          applicationId == other.applicationId &&
          applicationName == other.applicationName &&
          applicationVersion == other.applicationVersion &&
          applicationVersionName == other.applicationVersionName;

  @override
  int get hashCode =>
      applicationId.hashCode ^
      applicationName.hashCode ^
      applicationVersion.hashCode ^
      applicationVersionName.hashCode;
}
