# Change log

All notable changes to the LaunchDarkly Common Client will be documented in this file. This project adheres to [Semantic Versioning](https://semver.org).

## [1.9.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.8.0...launchdarkly_common_client-v1.9.0) (2026-02-10)


### Features

* Add support for per-context summary events. ([#245](https://github.com/launchdarkly/flutter-client-sdk/issues/245)) ([095baeb](https://github.com/launchdarkly/flutter-client-sdk/commit/095baebe92197dc365fcab9aeb1873ed7a660ad9))

## [1.8.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.7.0...launchdarkly_common_client-v1.8.0) (2025-11-05)


### Features

* Add support for ping stream. ([3f6fd2b](https://github.com/launchdarkly/flutter-client-sdk/commit/3f6fd2b1ace248441b3e59e6892ed404b5cfe286))


### Bug Fixes

* Expose polling configuration type. ([3f6fd2b](https://github.com/launchdarkly/flutter-client-sdk/commit/3f6fd2b1ace248441b3e59e6892ed404b5cfe286))

## [1.7.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.6.2...launchdarkly_common_client-v1.7.0) (2025-09-12)


### Features

* Add experimental plugin support. ([#225](https://github.com/launchdarkly/flutter-client-sdk/issues/225)) ([5bd9ce7](https://github.com/launchdarkly/flutter-client-sdk/commit/5bd9ce7035d4e0d6e56f8d2193c103a46bc8040e))
* Add support for hooks. ([#220](https://github.com/launchdarkly/flutter-client-sdk/issues/220)) ([6e7a26d](https://github.com/launchdarkly/flutter-client-sdk/commit/6e7a26da6407afbf28f3ff2599ef35b536cd2db5))
* Internal environment ID support. ([#217](https://github.com/launchdarkly/flutter-client-sdk/issues/217)) ([71b522b](https://github.com/launchdarkly/flutter-client-sdk/commit/71b522b78dca92d81b901a0e07089d1f1f5cc415))


### Bug Fixes

* Change hook data values to `dynamic` from `LDValue`. ([d7720f3](https://github.com/launchdarkly/flutter-client-sdk/commit/d7720f3091cf31ed276a00a9a20dcf34b5dc7f28))
* Export required plugin meta-data types. ([d7720f3](https://github.com/launchdarkly/flutter-client-sdk/commit/d7720f3091cf31ed276a00a9a20dcf34b5dc7f28))

## [1.6.2](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.6.1...launchdarkly_common_client-v1.6.2) (2025-09-03)


### Bug Fixes

* improves handling of invalid contexts and adds SSE Client logging. ([#207](https://github.com/launchdarkly/flutter-client-sdk/issues/207)) ([fcab81f](https://github.com/launchdarkly/flutter-client-sdk/commit/fcab81f006f6efd78206756447d2587f87b8c43c))

## [1.6.1](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.6.0...launchdarkly_common_client-v1.6.1) (2025-05-09)


### Bug Fixes

* Bump launchdarkly_dart_common to v1.6.0 ([#201](https://github.com/launchdarkly/flutter-client-sdk/issues/201)) ([122a72b](https://github.com/launchdarkly/flutter-client-sdk/commit/122a72b609b600590c39fdbf14307f1f81aff13b))

## [1.6.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.5.0...launchdarkly_common_client-v1.6.0) (2025-04-21)


### Features

* Add support for WASM ([#191](https://github.com/launchdarkly/flutter-client-sdk/issues/191)) ([33431eb](https://github.com/launchdarkly/flutter-client-sdk/commit/33431eb34e1d69e8b0c10f522b40c8a339fe1b5c))
* **deps:** Update depdendency versions for launchdarkly_common_client ([#196](https://github.com/launchdarkly/flutter-client-sdk/issues/196)) ([0646c2a](https://github.com/launchdarkly/flutter-client-sdk/commit/0646c2aaaffb8fd17c61646bed815cc7898fa428))

## [1.5.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.4.1...launchdarkly_common_client-v1.5.0) (2025-04-18)


### Features

* **deps:** Update minimum required Flutter version to 3.22.0 and minimum required Dart version to 3.4.0 ([#186](https://github.com/launchdarkly/flutter-client-sdk/issues/186)) ([1b36324](https://github.com/launchdarkly/flutter-client-sdk/commit/1b363247ef5d01e08baa480e4f5ed4b644397dad))

## [1.4.1](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.4.0...launchdarkly_common_client-v1.4.1) (2024-10-31)


### Bug Fixes

* propagating package versions ([#175](https://github.com/launchdarkly/flutter-client-sdk/issues/175)) ([f398d24](https://github.com/launchdarkly/flutter-client-sdk/commit/f398d2493da4faa1a06e7e74829bfb1b1817d55a))

## [1.4.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.3.1...launchdarkly_common_client-v1.4.0) (2024-10-31)


### Features

* Adds support for client-side prerequisite events ([#172](https://github.com/launchdarkly/flutter-client-sdk/issues/172)) ([7a042c2](https://github.com/launchdarkly/flutter-client-sdk/commit/7a042c2047798831b62ea29243313d7e411d22e1))

## [1.3.1](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.3.0...launchdarkly_common_client-v1.3.1) (2024-10-09)


### Bug Fixes

* Use correct flag version in evaluation events. ([#166](https://github.com/launchdarkly/flutter-client-sdk/issues/166)) ([5d3e826](https://github.com/launchdarkly/flutter-client-sdk/commit/5d3e826bbb2345b259b6ac29732440b58f29b673))

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
