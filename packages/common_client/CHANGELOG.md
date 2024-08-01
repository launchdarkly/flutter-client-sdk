# Change log

All notable changes to the LaunchDarkly Common Client will be documented in this file. This project adheres to [Semantic Versioning](https://semver.org).

## [1.3.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.2.0...launchdarkly_common_client-v1.3.0) (2024-07-31)


### Features

* Add support for waiting for non-cached values. ([#160](https://github.com/launchdarkly/flutter-client-sdk/issues/160)) ([28f7efa](https://github.com/launchdarkly/flutter-client-sdk/commit/28f7efa6128b937a4626fe4b4ca60b9e64db1641))

## [1.2.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.1.0...launchdarkly_common_client-v1.2.0) (2024-03-18)


### Features

* Update common-client to use common 1.2.0 ([#144](https://github.com/launchdarkly/flutter-client-sdk/issues/144)) ([cd704ec](https://github.com/launchdarkly/flutter-client-sdk/commit/cd704ec0f6814652fc8bd2afa9fef78474608079))

## [1.1.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.0.2...launchdarkly_common_client-v1.1.0) (2024-03-06)


### Features

* Update common-client to use common 1.1.0 ([#138](https://github.com/launchdarkly/flutter-client-sdk/issues/138)) ([c54c90e](https://github.com/launchdarkly/flutter-client-sdk/commit/c54c90eef95308112a33fdd8343eff0a3ea8322c))

## [1.0.2](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.0.1...launchdarkly_common_client-v1.0.2) (2024-01-31)


### Bug Fixes

* Change LDAttributesBuilder visibility. ([#123](https://github.com/launchdarkly/flutter-client-sdk/issues/123)) ([e25803a](https://github.com/launchdarkly/flutter-client-sdk/commit/e25803a8dc15a7256cd1c896511bdaac51ebf67d))

## [1.0.1](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.0.0...launchdarkly_common_client-v1.0.1) (2024-01-30)


### Bug Fixes

* Flutter client should depend only on common client. ([#113](https://github.com/launchdarkly/flutter-client-sdk/issues/113)) ([edfd06d](https://github.com/launchdarkly/flutter-client-sdk/commit/edfd06d24e30915c0608766e5abcc9290aaf6244))

## [1.0.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v0.1.0...launchdarkly_common_client-v1.0.0) (2024-01-30)


### Features

* Implement support for REPORT for streaming. ([#96](https://github.com/launchdarkly/flutter-client-sdk/issues/96)) ([1de6079](https://github.com/launchdarkly/flutter-client-sdk/commit/1de60797e2edaac2fdf38f829ee4e3f15260f963))
* Update common client to release packages. ([#111](https://github.com/launchdarkly/flutter-client-sdk/issues/111)) ([4ae05a5](https://github.com/launchdarkly/flutter-client-sdk/commit/4ae05a5d7cc950c2f29b07624d73463ce8f7794c))


### Bug Fixes

* anonymous context keys and auto env context keys are now in separate namespaces ([#104](https://github.com/launchdarkly/flutter-client-sdk/issues/104)) ([06fb955](https://github.com/launchdarkly/flutter-client-sdk/commit/06fb95589fca1b56146442e8db88e56923449962))
* Collect attributes once. ([#98](https://github.com/launchdarkly/flutter-client-sdk/issues/98)) ([45dcab1](https://github.com/launchdarkly/flutter-client-sdk/commit/45dcab15cf8e069277d15c05064e17dda0e51d4e))
* making context builder easier to use ([#106](https://github.com/launchdarkly/flutter-client-sdk/issues/106)) ([28f0370](https://github.com/launchdarkly/flutter-client-sdk/commit/28f0370eb0a1b86af51d207948b2f4169a937eef))
* Use event source reset on invalid payloads. ([#103](https://github.com/launchdarkly/flutter-client-sdk/issues/103)) ([53ab27d](https://github.com/launchdarkly/flutter-client-sdk/commit/53ab27d002b0d2a37669b345b1337da1f428277d))

## [0.1.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v0.0.2...launchdarkly_common_client-v0.1.0) (2024-01-24)


### Features

* Update common/client/event source dependencies. ([#87](https://github.com/launchdarkly/flutter-client-sdk/issues/87)) ([9acbab3](https://github.com/launchdarkly/flutter-client-sdk/commit/9acbab3bbe3ca9a1c63923ea4c95f0eb0dd1177b))


### Bug Fixes

* Fix sink not closed lint. ([#66](https://github.com/launchdarkly/flutter-client-sdk/issues/66)) ([051fd9c](https://github.com/launchdarkly/flutter-client-sdk/commit/051fd9cfc405f23e0bac64da90b9277ccdf5e188))
* Remove flutter dependency from event source. ([#65](https://github.com/launchdarkly/flutter-client-sdk/issues/65)) ([d557692](https://github.com/launchdarkly/flutter-client-sdk/commit/d557692ef7d146a5c691d3b8f64f10726f12add3))

## [0.0.2] - 2024-01-22

### Changed

- Updated dependency for event source client to `0.0.2`.

## [0.0.1] - 2024-01-22

Initial alpha version.
