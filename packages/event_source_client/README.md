# LaunchDarkly Event Source Client

*This package is a **beta** version and should not be considered ready for production use while this message is visible.*

## Overview

This package allows Dart developers to consume Server-Sent-Events (SSE) from a remote API. The SSE specification is defined here: [https://html.spec.whatwg.org/multipage/server-sent-events.html](https://html.spec.whatwg.org/multipage/server-sent-events.html#server-sent-events)

This library is primarily intended for use by LaunchDarkly libraries.

## Testing

This package is tested against a centralized test harness. For information on running the tests check: [SSE Contract Tests](https://github.com/launchdarkly/flutter-client-sdk/blob/main/apps/flutter_client_contract_test_service/README.md).

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