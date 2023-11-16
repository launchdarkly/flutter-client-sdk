/// [launchdarkly_flutter_client_sdk] provides a Flutter wrapper around the LaunchDarkly mobile SDKs for
/// [Android](https://github.com/launchdarkly/android-client-sdk) and [iOS](https://github.com/launchdarkly/ios-client-sdk).
///
/// A complete [reference guide](https://docs.launchdarkly.com/sdk/client-side/flutter) is available on the LaunchDarkly
/// documentation site.
library launchdarkly_flutter_client_sdk;

// Re-export the client package, which includes the common dependencies as well.
export 'package:launchdarkly_dart_client/ld_client.dart';

export 'src/ld_client.dart'
    show LDClient, LDFlagsReceivedCallback, LDFlagUpdatedCallback;
