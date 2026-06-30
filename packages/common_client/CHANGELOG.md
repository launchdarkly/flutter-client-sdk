# Change log

All notable changes to the LaunchDarkly Common Client will be documented in this file. This project adheres to [Semantic Versioning](https://semver.org).

## [1.14.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.13.0...launchdarkly_common_client-v1.14.0) (2026-06-29)


### Features

* add an initial connection mode to the FDv2 data system config ([#318](https://github.com/launchdarkly/flutter-client-sdk/issues/318)) ([5b980ab](https://github.com/launchdarkly/flutter-client-sdk/commit/5b980abac0ee1d66b3e20978efd84c5a37686794))
* Add FDv2 payload application via FlagManager.applyChanges ([#299](https://github.com/launchdarkly/flutter-client-sdk/issues/299)) ([66c2554](https://github.com/launchdarkly/flutter-client-sdk/commit/66c255498f852fa534569a6afc33ef24272c3fa4))
* Add FDv2 payload handling to the data source event handler ([#305](https://github.com/launchdarkly/flutter-client-sdk/issues/305)) ([761ed9d](https://github.com/launchdarkly/flutter-client-sdk/commit/761ed9dae238d9ee6f897e54e2872858cd759270))
* Add FDv2 source manager ([#298](https://github.com/launchdarkly/flutter-client-sdk/issues/298)) ([43d899e](https://github.com/launchdarkly/flutter-client-sdk/commit/43d899e7f675612cf67a53e3e5338ce3cf1dc3d1))
* Add FDv2 streaming source factories and query-parameter authentication ([7b46ac6](https://github.com/launchdarkly/flutter-client-sdk/commit/7b46ac6a05a97cba9aaeed098ecef4227883fc96))
* Add FDv2 synchronizer fallback and recovery conditions ([#297](https://github.com/launchdarkly/flutter-client-sdk/issues/297)) ([17f7b4e](https://github.com/launchdarkly/flutter-client-sdk/commit/17f7b4e61af746b3775ddf481ae4de182e3c9937))
* Add the FDv2 data source orchestrator ([#307](https://github.com/launchdarkly/flutter-client-sdk/issues/307)) ([eb9a35f](https://github.com/launchdarkly/flutter-client-sdk/commit/eb9a35f746d7dc172c388841c59714a0585066e7))
* Add the FDv2 data system and expose it through configuration ([#310](https://github.com/launchdarkly/flutter-client-sdk/issues/310)) ([61a1e59](https://github.com/launchdarkly/flutter-client-sdk/commit/61a1e59ddd7095599f3645a7b9fbfedf8ed94dd7))
* Centralize platform credential handling in CredentialConfig ([#300](https://github.com/launchdarkly/flutter-client-sdk/issues/300)) ([c677c3d](https://github.com/launchdarkly/flutter-client-sdk/commit/c677c3d19d010194ca6036fc6830d30d8e6f2129))
* honor the FDv1 fallback directive on success, error, and goodbye ([#312](https://github.com/launchdarkly/flutter-client-sdk/issues/312)) ([1c35867](https://github.com/launchdarkly/flutter-client-sdk/commit/1c358670b8b85f9278c94d6e1bc98955ffdc5446))
* Translate FDv2 payloads at the data source layer ([7b46ac6](https://github.com/launchdarkly/flutter-client-sdk/commit/7b46ac6a05a97cba9aaeed098ecef4227883fc96))
* Update launchdarkly_event_source_client to version 2.2.0 ([#302](https://github.com/launchdarkly/flutter-client-sdk/issues/302)) ([cb6a5c0](https://github.com/launchdarkly/flutter-client-sdk/commit/cb6a5c0a3fa0fb68aeb6bf72a52fdd0191cbaa7e))
* Update launchdarkly_event_source_client to version 3.0.0 ([#317](https://github.com/launchdarkly/flutter-client-sdk/issues/317)) ([15861f8](https://github.com/launchdarkly/flutter-client-sdk/commit/15861f8cc62a7b8e0b33435382bddff1fc7a9426))


### Bug Fixes

* Close the final initializer on exhaustion; document the source manager contract ([#304](https://github.com/launchdarkly/flutter-client-sdk/issues/304)) ([b20c35e](https://github.com/launchdarkly/flutter-client-sdk/commit/b20c35ea34c1618bbf66684e9b2f301145542a33))

## [1.13.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.12.0...launchdarkly_common_client-v1.13.0) (2026-06-09)


### Features

* Add StateDebounceManager to common_client ([#291](https://github.com/launchdarkly/flutter-client-sdk/issues/291)) ([e9f8183](https://github.com/launchdarkly/flutter-client-sdk/commit/e9f81839a7d077860e986cf2de415c0ae577cad9))

## [1.12.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.11.0...launchdarkly_common_client-v1.12.0) (2026-06-04)


### Features

* Wire FDv2 connection-mode resolution in flutter SDK ([#280](https://github.com/launchdarkly/flutter-client-sdk/issues/280)) ([ef8ad39](https://github.com/launchdarkly/flutter-client-sdk/commit/ef8ad391173d5c657b4535e77b1af8ef698c75ae))

## [1.11.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.10.0...launchdarkly_common_client-v1.11.0) (2026-06-03)


### Features

* Wire FDv2 connection-mode resolution in common_client ([#279](https://github.com/launchdarkly/flutter-client-sdk/issues/279)) ([ceb931f](https://github.com/launchdarkly/flutter-client-sdk/commit/ceb931fdbe108fc52eeabc48ababd5727e09f8be))

## [1.10.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_common_client-v1.9.0...launchdarkly_common_client-v1.10.0) (2026-05-29)


### Features

* Add FDv2 connection mode, resolved-mode, and resolution types ([#274](https://github.com/launchdarkly/flutter-client-sdk/issues/274)) ([bf5b165](https://github.com/launchdarkly/flutter-client-sdk/commit/bf5b165727ed87994ee01ed41fc8b876bf6003fb))
* add FDv2 protocol foundation types and state machine ([#253](https://github.com/launchdarkly/flutter-client-sdk/issues/253)) ([543fc65](https://github.com/launchdarkly/flutter-client-sdk/commit/543fc65d4505a8dcbc4e9671a54e3061f0d98807))
* add FDv2 requestor and polling base ([9ce5fdf](https://github.com/launchdarkly/flutter-client-sdk/commit/9ce5fdf2d86a26fe6536663033c08f1a7249a802))
* add Initializer and Synchronizer source contracts  ([9ce5fdf](https://github.com/launchdarkly/flutter-client-sdk/commit/9ce5fdf2d86a26fe6536663033c08f1a7249a802))
* add polling and cache sources for FDv2 ([#261](https://github.com/launchdarkly/flutter-client-sdk/issues/261)) ([2841cc6](https://github.com/launchdarkly/flutter-client-sdk/commit/2841cc63a758f6deb7e41c0ea4d0151352587b1a))
* add SSECapability surface to SSEClient ([#266](https://github.com/launchdarkly/flutter-client-sdk/issues/266)) ([c78480c](https://github.com/launchdarkly/flutter-client-sdk/commit/c78480c5cb6a7196d5c3d0e25c75eb56a77b043c))
* FDv2 streaming base, initializer, and synchronizer ([#267](https://github.com/launchdarkly/flutter-client-sdk/issues/267)) ([2d2f223](https://github.com/launchdarkly/flutter-client-sdk/commit/2d2f2235fccb3bce1f3e4e82c4b6b85cfdf3357c))
* safeGetPluginHooks helper in common_client ([#282](https://github.com/launchdarkly/flutter-client-sdk/issues/282)) ([08f0538](https://github.com/launchdarkly/flutter-client-sdk/commit/08f0538cfe01c22d0119fe6d5798fb7799ccda85))
* Update launchdarkly_event_source_client to version 2.1.0 ([#276](https://github.com/launchdarkly/flutter-client-sdk/issues/276)) ([52455aa](https://github.com/launchdarkly/flutter-client-sdk/commit/52455aa9987750388b7c6c4d86b76e15ebe54059))


### Bug Fixes

* Correct conditional-request header and sanitize network error log in FDv1 polling requestor ([#263](https://github.com/launchdarkly/flutter-client-sdk/issues/263)) ([18d78ce](https://github.com/launchdarkly/flutter-client-sdk/commit/18d78ce9ae724aa6af40aeffffed4e441fdbfe47))
* Update launchdarkly_dart_common to version 1.8.1 ([#277](https://github.com/launchdarkly/flutter-client-sdk/issues/277)) ([0e5301d](https://github.com/launchdarkly/flutter-client-sdk/commit/0e5301d1b61830b0fb3892932aaca0b1b1609014))

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
