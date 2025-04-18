# Change log

All notable changes to the LaunchDarkly Dart Common will be documented in this file. This project adheres to [Semantic Versioning](https://semver.org).

## [1.4.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_dart_common-v1.3.0...launchdarkly_dart_common-v1.4.0) (2025-04-18)


### Features

* **deps:** Update minimum required Flutter version to 3.22.0 and minimum required Dart version to 3.4.0 ([#186](https://github.com/launchdarkly/flutter-client-sdk/issues/186)) ([1b36324](https://github.com/launchdarkly/flutter-client-sdk/commit/1b363247ef5d01e08baa480e4f5ed4b644397dad))

## [1.3.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_dart_common-v1.2.1...launchdarkly_dart_common-v1.3.0) (2024-10-31)


### Features

* Adds support for client-side prerequisite events ([#172](https://github.com/launchdarkly/flutter-client-sdk/issues/172)) ([7a042c2](https://github.com/launchdarkly/flutter-client-sdk/commit/7a042c2047798831b62ea29243313d7e411d22e1))

## [1.2.1](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_dart_common-v1.2.0...launchdarkly_dart_common-v1.2.1) (2024-10-09)


### Bug Fixes

* Use correct flag version in evaluation events. ([#166](https://github.com/launchdarkly/flutter-client-sdk/issues/166)) ([5d3e826](https://github.com/launchdarkly/flutter-client-sdk/commit/5d3e826bbb2345b259b6ac29732440b58f29b673))

## [1.2.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_dart_common-v1.1.0...launchdarkly_dart_common-v1.2.0) (2024-03-14)


### Features

* Always inline contexts for feature events ([#76](https://github.com/launchdarkly/flutter-client-sdk/issues/76)) ([b2ebcbf](https://github.com/launchdarkly/flutter-client-sdk/commit/b2ebcbfd8c3c817595821f91ffb7ac02687bb41f))
* Redact anonymous attributes within feature events ([#77](https://github.com/launchdarkly/flutter-client-sdk/issues/77)) ([4387375](https://github.com/launchdarkly/flutter-client-sdk/commit/4387375f65c544f92cb65ce9882bb436ae95631b))

## [1.1.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_dart_common-v1.0.0...launchdarkly_dart_common-v1.1.0) (2024-03-05)


### Features

* Add LDContext equality comparison. ([#135](https://github.com/launchdarkly/flutter-client-sdk/issues/135)) ([3591ddc](https://github.com/launchdarkly/flutter-client-sdk/commit/3591ddce335c756518ac792f219b41f496b300ac))
* Support converting LDValue to/from dynamic. ([#134](https://github.com/launchdarkly/flutter-client-sdk/issues/134)) ([2a7ebf9](https://github.com/launchdarkly/flutter-client-sdk/commit/2a7ebf97382bc6141ac3d70fc600ae185d0c5e84))

## [1.0.0](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_dart_common-v0.0.2...launchdarkly_dart_common-v1.0.0) (2024-01-30)


### Features

* Implement support for REPORT for streaming. ([#96](https://github.com/launchdarkly/flutter-client-sdk/issues/96)) ([1de6079](https://github.com/launchdarkly/flutter-client-sdk/commit/1de60797e2edaac2fdf38f829ee4e3f15260f963))


### Bug Fixes

* Collect attributes once. ([#98](https://github.com/launchdarkly/flutter-client-sdk/issues/98)) ([45dcab1](https://github.com/launchdarkly/flutter-client-sdk/commit/45dcab15cf8e069277d15c05064e17dda0e51d4e))
* making context builder easier to use ([#106](https://github.com/launchdarkly/flutter-client-sdk/issues/106)) ([28f0370](https://github.com/launchdarkly/flutter-client-sdk/commit/28f0370eb0a1b86af51d207948b2f4169a937eef))

## [0.0.2](https://github.com/launchdarkly/flutter-client-sdk/compare/launchdarkly_dart_common-v0.0.1...launchdarkly_dart_common-v0.0.2) (2024-01-24)


### Bug Fixes

* Fix sink not closed lint. ([#66](https://github.com/launchdarkly/flutter-client-sdk/issues/66)) ([051fd9c](https://github.com/launchdarkly/flutter-client-sdk/commit/051fd9cfc405f23e0bac64da90b9277ccdf5e188))
* Remove redundant context encoding ([#75](https://github.com/launchdarkly/flutter-client-sdk/issues/75)) ([064af19](https://github.com/launchdarkly/flutter-client-sdk/commit/064af19479d8a112399d5acfdf17b11099937d33))

## [0.0.1] - 2024-01-22

Initial alpha version.
