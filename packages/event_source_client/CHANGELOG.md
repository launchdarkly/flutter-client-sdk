# Change log

All notable changes to the LaunchDarkly Event Source Client SDK will be documented in this file. This project adheres to [Semantic Versioning](https://semver.org).

## [2.0.1](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_event_source_client-v2.0.0...launchdarkly_event_source_client-v2.0.1) (2025-09-04)


### Bug Fixes

* Fix analysis issues. ([#219](https://github.com/launchdarkly/flutter-client-sdk/issues/219)) ([a061270](https://github.com/launchdarkly/flutter-client-sdk/commit/a061270bb7bc26728513c41a7d73faa335cfac06))

## [2.0.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_event_source_client-v1.2.1...launchdarkly_event_source_client-v2.0.0) (2025-09-03)


### ⚠ BREAKING CHANGES

* Add support for getting headers on event source connection. ([#208](https://github.com/launchdarkly/flutter-client-sdk/issues/208))

### Features

* Add support for getting headers on event source connection. ([#208](https://github.com/launchdarkly/flutter-client-sdk/issues/208)) ([9f0b1e4](https://github.com/launchdarkly/flutter-client-sdk/commit/9f0b1e41b238209b60de49a1f05324c2080675fc))

## [1.2.1](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_event_source_client-v1.2.0...launchdarkly_event_source_client-v1.2.1) (2025-09-02)


### Bug Fixes

* improves handling of invalid contexts and adds SSE Client logging. ([#207](https://github.com/launchdarkly/flutter-client-sdk/issues/207)) ([fcab81f](https://github.com/launchdarkly/flutter-client-sdk/commit/fcab81f006f6efd78206756447d2587f87b8c43c))

## [1.2.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_event_source_client-v1.1.0...launchdarkly_event_source_client-v1.2.0) (2025-04-21)


### Features

* Add support for WASM ([#191](https://github.com/launchdarkly/flutter-client-sdk/issues/191)) ([33431eb](https://github.com/launchdarkly/flutter-client-sdk/commit/33431eb34e1d69e8b0c10f522b40c8a339fe1b5c))

## [1.1.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_event_source_client-v1.0.0...launchdarkly_event_source_client-v1.1.0) (2025-04-18)


### Features

* **deps:** Update minimum required Flutter version to 3.22.0 and minimum required Dart version to 3.4.0 ([#186](https://github.com/launchdarkly/flutter-client-sdk/issues/186)) ([1b36324](https://github.com/launchdarkly/flutter-client-sdk/commit/1b363247ef5d01e08baa480e4f5ed4b644397dad))

## [1.0.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_event_source_client-v0.0.3...launchdarkly_event_source_client-v1.0.0) (2024-01-30)


### Features

* Add restart support to the SSE client. ([#102](https://github.com/launchdarkly/flutter-client-sdk/issues/102)) ([a4c1ede](https://github.com/launchdarkly/flutter-client-sdk/commit/a4c1eded28408531cec9d94efa59a4d31c8b497d))
* Implement backoff, with jitter, for web targets. ([#105](https://github.com/launchdarkly/flutter-client-sdk/issues/105)) ([9a0d618](https://github.com/launchdarkly/flutter-client-sdk/commit/9a0d618a6d860723596f881cf6c776963ea78f69))
* Implement LDClient methods. ([#38](https://github.com/launchdarkly/flutter-client-sdk/issues/38)) ([a105bed](https://github.com/launchdarkly/flutter-client-sdk/commit/a105bed73fe539253c47fb983ece9d77e911caf1))
* Implement streaming data source. ([#33](https://github.com/launchdarkly/flutter-client-sdk/issues/33)) ([5931665](https://github.com/launchdarkly/flutter-client-sdk/commit/5931665cf892a271f9286250949e8e344ad6d51d))
* Implement support for REPORT for streaming. ([#96](https://github.com/launchdarkly/flutter-client-sdk/issues/96)) ([1de6079](https://github.com/launchdarkly/flutter-client-sdk/commit/1de60797e2edaac2fdf38f829ee4e3f15260f963))
* initial support for sse client ([f7168aa](https://github.com/launchdarkly/flutter-client-sdk/commit/f7168aad0bccc9db37834bc669cbf8b12ee08098))


### Bug Fixes

* Fix sink not closed lint. ([#66](https://github.com/launchdarkly/flutter-client-sdk/issues/66)) ([051fd9c](https://github.com/launchdarkly/flutter-client-sdk/commit/051fd9cfc405f23e0bac64da90b9277ccdf5e188))
* Remove flutter dependency from event source. ([#65](https://github.com/launchdarkly/flutter-client-sdk/issues/65)) ([d557692](https://github.com/launchdarkly/flutter-client-sdk/commit/d557692ef7d146a5c691d3b8f64f10726f12add3))
* Use event source reset on invalid payloads. ([#103](https://github.com/launchdarkly/flutter-client-sdk/issues/103)) ([53ab27d](https://github.com/launchdarkly/flutter-client-sdk/commit/53ab27d002b0d2a37669b345b1337da1f428277d))

## [0.0.3](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_event_source_client-v0.0.2...launchdarkly_event_source_client-v0.0.3) (2024-01-23)


### Bug Fixes

* Fix sink not closed lint. ([#66](https://github.com/launchdarkly/flutter-client-sdk/issues/66)) ([051fd9c](https://github.com/launchdarkly/flutter-client-sdk/commit/051fd9cfc405f23e0bac64da90b9277ccdf5e188))
* Remove flutter dependency from event source. ([#65](https://github.com/launchdarkly/flutter-client-sdk/issues/65)) ([d557692](https://github.com/launchdarkly/flutter-client-sdk/commit/d557692ef7d146a5c691d3b8f64f10726f12add3))

## [0.0.2] - 2024-01-22

### Fix

- Remove dependency on flutter SDK.

## [0.0.1] - 2024-01-22

Initial alpha version.
