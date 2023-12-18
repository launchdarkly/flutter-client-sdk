import '../defaults/credential_type.dart';
import '../defaults/default_config.dart';

/// Allows loading a credential, either a client-side ID or mobile key, from
/// environment variables.
final class CredentialSource {
  /// Load a credential, either a client-side ID or mobile key, from
  /// the environment.
  ///
  /// A client-side ID may be specified as `LAUNCHDARKLY_CLIENT_SIDE_ID`.
  ///
  /// A mobile key may be specified as `LAUNCHDARKLY_MOBILE_KEY`.
  ///
  /// The [CredentialSource] will expect one of these two environment variables
  /// to be set, but not both. The intent is that the built package will
  /// contain only the type of credential it needs.
  ///
  /// The credential can be provided on the command line when building
  /// or running the application using the SDK.
  ///
  /// Browser example:
  /// ```bash
  /// flutter run --dart-define LAUNCHDARKLY_CLIENT_SIDE_ID=MyClientSideId -d Chrome
  /// ```
  ///
  /// Running a windows app:
  /// ```bash
  /// flutter run --dart-define LAUNCHDARKLY_MOBILE_KEY=MyMobileKey -d windows
  /// ```
  static String fromEnvironment() {
    final clientSideId =
        const String.fromEnvironment('LAUNCHDARKLY_CLIENT_SIDE_ID');
    final mobileKey = const String.fromEnvironment('LAUNCHDARKLY_MOBILE_KEY');

    if (clientSideId != '' && mobileKey != '') {
      throw Exception('When building an application using the SDK you should '
          'include either a client-side ID, or a mobile key, but not both');
    }

    switch (DefaultConfig.credentialConfig.credentialType) {
      case CredentialType.mobileKey:
        if (mobileKey == '') {
          throw Exception(
              'The mobile key was not specified, but must be for this build '
              'type. All non-web builds use the mobile key.');
        }
        return mobileKey;
      case CredentialType.clientSideId:
        if (clientSideId == '') {
          throw Exception(
              'The client-side ID was not specified, but must be for this build'
              ' type. Web builds required a client-side ID');
        }
        return clientSideId;
    }
  }
}
