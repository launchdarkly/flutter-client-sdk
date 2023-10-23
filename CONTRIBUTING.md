Contributing to the LaunchDarkly Client SDK for Flutter
================================================

LaunchDarkly has published an [SDK contributor's guide](https://docs.launchdarkly.com/sdk/concepts/contributors-guide) that provides a detailed explanation of how our SDKs work. See below for additional information on how to contribute to this SDK.

Submitting bug reports and feature requests
------------------

The LaunchDarkly SDK team monitors the [issue tracker](https://github.com/launchdarkly/flutter-client-sdk/issues) in the SDK repository. Bug reports and feature requests specific to this SDK should be filed in this issue tracker. The SDK team will respond to all newly filed issues within two business days.

Submitting pull requests
------------------

We encourage pull requests and other contributions from the community. Before submitting pull requests, ensure that all temporary or unintended code is removed. Don't worry about adding reviewers to the pull request; the LaunchDarkly SDK team will add themselves. The SDK team will acknowledge all pull requests within two business days.

Build instructions
------------------

### Prerequisites

See the [Flutter install](https://flutter.dev/docs/get-started/install) page for setting up Flutter for building Android and iOS plugins.

This repository uses [Melos](https://github.com/invertase/melos) to manage the project and its dependencies.

To install Melos you can run:
```
dart pub global activate melos
```

### Building

Install dependencies using `melos bootstrap`

The `melos` command line tool can be used to build and run the example application for manual testing. Run `melos run launchdarkly_flutter_example` in the root of the repository.

### Testing

To run the unit tests for the SDK, run `melos run test` in the SDK repo. These tests only cover the pure Dart behavior of the SDK, not the native plugin code that wraps the native SDKs.
