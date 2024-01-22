# LaunchDarkly Client-side SDK for Flutter

*This version of the SDK is a **beta** version and should not be considered ready for production use while this message is visible.*

[![Action Status](https://github.com/launchdarkly/flutter-client-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/launchdarkly/flutter-client-sdk/actions/workflows/ci.yml)
[![Pub](https://img.shields.io/pub/v/launchdarkly_flutter_client_sdk.svg)](https://pub.dev/packages/launchdarkly_flutter_client_sdk)

## LaunchDarkly overview

[LaunchDarkly](https://www.launchdarkly.com) is a feature management platform that serves trillions of feature flags daily to help teams build better software, faster. [Get started](https://docs.launchdarkly.com/home/getting-started) using LaunchDarkly today!

[![Twitter Follow](https://img.shields.io/twitter/follow/launchdarkly.svg?style=social&label=Follow&maxAge=2592000)](https://twitter.com/intent/follow?screen_name=launchdarkly)

## Supported Platforms

See the [pubspec.yaml](https://github.com/launchdarkly/flutter-client-sdk/blob/main/packages/flutter_client_sdk/pubspec.yaml) file for Flutter version requirements.

This SDK supports Android, iOS, Linux, macOS, Web, and Windows.

The underlying API support requirements are determined by the native plugins used by the SDK.

These include:
- [shared_preferences](https://pub.dev/packages/shared_preferences): Used for persistent caching for flag payloads and other data.
- [connectivity_plus](https://pub.dev/packages/connectivity_plus): Used for detecting network status.
- [package_info_plus]() and [device_info_plus](): Used to for the [automatic environment attributes](https://docs.launchdarkly.com/sdk/features/environment-attributes/?q=environ) feature.

## Getting started

Refer to the [SDK documentation](https://docs.launchdarkly.com/sdk/client-side/flutter#getting-started) for instructions on getting started with using the SDK.

## Organization

The repository is a monorepo containing the packages required to make the SDK as well as testing
and example applications.

| Directory                                 | Readme                                                                                      | Description                                                                                                                                                                                         |
|-------------------------------------------|---------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| .github                                   |                                                                                             | Contains CI and release process workflows and actions.                                                                                                                                              |
| packages                                  |                                                                                             | Contains flutter/dart libraries.                                                                                                                                                                    |
| packages/flutter_client_sdk               | [Flutter Client SDK](packages/flutter_client_sdk/README.md)                                 | Package which implements the LaunchDarkly client-side SDK for flutter.                                                                                                                              |
| packages/common                           | [Common](packages/common/README.md)                                                         | Package which contains common code for dart based SDKs. Currently there is only a client-side SDK, but this directory should only contain code tha would apply to both client and server-side SDKs. |
| packages/client                           | [Common Client](packages/common_client/README.md)                                           | Package containing code that is specific to client-side SDKs, but not specific to flutter.                                                                                                          |
| packages/event_source_client              | [Event Source Client](packages/event_source_client/README.md)                               | Package implementing support for SSE.                                                                                                                                                               |
| apps                                      |                                                                                             | Contains sample and test applications.                                                                                                                                                              |
| apps/sse_contract_test_service            | [SSE Contract Test Service](apps/sse_contract_test_service/README.md)                       | This application is used to test the SSE implementation used by the SDK.                                                                                                                            |
| apps/flutter_client_contract_test_service | [Flutter Client Contract Test Service](apps/flutter_client_contract_test_service/README.md) | This application is used to test the functionality of the SDK.                                                                                                                                      |
| architecture                              |                                                                                             | Contains diagrams and other supporting architecture documents.                                                                                                                                      |

## Learn more

Read our [documentation](https://docs.launchdarkly.com) for in-depth instructions on configuring and using LaunchDarkly. You can also head straight to the [complete reference guide for this SDK](https://docs.launchdarkly.com/sdk/client-side/flutter) or our [code-generated API documentation](https://launchdarkly.github.io/flutter-client-sdk/).

## Testing

We run integration tests for all our SDKs using a centralized test harness. This approach gives us the ability to test for consistency across SDKs. These tests cover each method in the SDK, and verify that event sending, flag evaluation, stream reconnection, and other aspects of the SDK all behave correctly.

## Contributing

We encourage pull requests and other contributions from the community. Read our [contributing guidelines](https://github.com/launchdarkly/flutter-client-sdk/blob/main/CONTRIBUTING.md) for instructions on how to contribute to this SDK.

## About LaunchDarkly

* LaunchDarkly is a feature management platform. We empower all teams to deliver and control their software. With LaunchDarkly, you can:
  * Roll out a new feature to a subset of your end users, such as a group of end users who opt in to a beta tester group, and gather feedback and bug reports from real-world use cases.
  * Gradually roll out a feature to an increasing percentage of customers, and track the effect that the feature has on key metrics. For instance, how likely is a customer to complete a purchase if they have feature A versus feature B?
  * Turn off a feature that is causing performance problems in production, without needing to re-deploy or even restart the application with a changed configuration file.
  * Grant access to certain features based on end user attributes, like payment plan. (For example, customers on the ‘gold’ plan have access to more features than customers in the ‘silver’ plan).
  * Disable parts of your application to facilitate maintenance, without taking everything offline.
* LaunchDarkly provides feature flag SDKs for a wide variety of languages and technologies. Read our [SDK documentation](https://docs.launchdarkly.com/sdk) for a complete list.
* Explore LaunchDarkly
  * [launchdarkly.com](https://www.launchdarkly.com/ "LaunchDarkly Main Website") for more information
  * [docs.launchdarkly.com](https://docs.launchdarkly.com/  "LaunchDarkly Documentation") for our documentation and SDK reference guides
  * [apidocs.launchdarkly.com](https://apidocs.launchdarkly.com/  "LaunchDarkly API Documentation") for our API documentation
  * [launchdarkly.com/blog](https://launchdarkly.com/blog/  "LaunchDarkly Blog") for the latest product updates
