# LaunchDarkly Sample Flutter Application

We've built a simple Flutter application that demonstrates how LaunchDarkly's SDK works.

## Getting Started

1. Make sure you have [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
2. Run `flutter pub get` in this directory.
3. Now you can run the application. By default the application will use either your mobile key or client-side ID based on platform and environment variables.
```shell
# Web uses the client-side ID.
$ flutter run --dart-define LAUNCHDARKLY_CLIENT_SIDE_ID=<my-client-side-id> -d Chrome
# All other platforms use the mobile key.
$ flutter run --dart-define LAUNCHDARKLY_MOBILE_KEY=<my-mobile-key> -d ios
```
Alternatively you may edit `lib/main.dart` and replace `CredentialSource.fromEnvironment()` with your
mobile key or client-side ID.

When running from an IDE you can edit the build configuration to include the `--dart-define` commands.
In Android studio these can be placed in the "Additional Run Args" when you edit the run configuration.

In order to run the example on a physical iOS device you will need to configure a development team and provisioning profile.

