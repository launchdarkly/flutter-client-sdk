# Change log

All notable changes to the LaunchDarkly Flutter client-side SDK will be documented in this file. This project adheres to [Semantic Versioning](https://semver.org).

## [4.13.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.12.0...4.13.0) (2025-09-26)


### Features

* Add support for connectivity_plus 7.0+ ([#232](https://github.com/launchdarkly/flutter-client-sdk/issues/232)) ([b31eb96](https://github.com/launchdarkly/flutter-client-sdk/commit/b31eb960c5d087dd78891a84c62235f7b19447c8)), closes [#231](https://github.com/launchdarkly/flutter-client-sdk/issues/231)

## [4.12.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.11.2...4.12.0) (2025-09-15)


### Features

* Add experimental plugin support. ([#225](https://github.com/launchdarkly/flutter-client-sdk/issues/225)) ([5bd9ce7](https://github.com/launchdarkly/flutter-client-sdk/commit/5bd9ce7035d4e0d6e56f8d2193c103a46bc8040e))
* Add hook support and experimental plugin support. ([#228](https://github.com/launchdarkly/flutter-client-sdk/issues/228)) ([b698905](https://github.com/launchdarkly/flutter-client-sdk/commit/b69890584945c5dd528f509061d430ff3fe0b180))
* Add support for hooks. ([#220](https://github.com/launchdarkly/flutter-client-sdk/issues/220)) ([6e7a26d](https://github.com/launchdarkly/flutter-client-sdk/commit/6e7a26da6407afbf28f3ff2599ef35b536cd2db5))
* Update version constraints for device_info_plus to allow using 12.x. ([9b5f530](https://github.com/launchdarkly/flutter-client-sdk/commit/9b5f530abd7a03129c2d4a8238a013412cca4f4f))
* Update version constraints for package_info_plus to allow using 9.x. ([9b5f530](https://github.com/launchdarkly/flutter-client-sdk/commit/9b5f530abd7a03129c2d4a8238a013412cca4f4f))


### Bug Fixes

* Change hook data values to `dynamic` from `LDValue`. ([d7720f3](https://github.com/launchdarkly/flutter-client-sdk/commit/d7720f3091cf31ed276a00a9a20dcf34b5dc7f28))
* Export required plugin meta-data types. ([d7720f3](https://github.com/launchdarkly/flutter-client-sdk/commit/d7720f3091cf31ed276a00a9a20dcf34b5dc7f28))

## [4.11.2](https://github.com/launchdarkly/flutter-client-sdk/compare/4.11.1...4.11.2) (2025-09-03)


### Bug Fixes

* improves handling of invalid contexts and adds SSE Client logging ([#215](https://github.com/launchdarkly/flutter-client-sdk/issues/215)) ([131a658](https://github.com/launchdarkly/flutter-client-sdk/commit/131a65854a22f9a29f46dcab953bec686a1b1a58))

## [4.11.1](https://github.com/launchdarkly/flutter-client-sdk/compare/4.11.0...4.11.1) (2025-05-12)


### Bug Fixes

* Bump launchdarkly_common_client to v1.6.1 ([#203](https://github.com/launchdarkly/flutter-client-sdk/issues/203)) ([6449b7f](https://github.com/launchdarkly/flutter-client-sdk/commit/6449b7f6f5215e92282dc2d927fc6847c5eae6c9))

## [4.11.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.10.0...4.11.0) (2025-04-21)


### Features

* Add support for WASM ([#191](https://github.com/launchdarkly/flutter-client-sdk/issues/191)) ([33431eb](https://github.com/launchdarkly/flutter-client-sdk/commit/33431eb34e1d69e8b0c10f522b40c8a339fe1b5c))
* **deps:** Update dependencies for launchdarkly_flutter_client_sdk ([#197](https://github.com/launchdarkly/flutter-client-sdk/issues/197)) ([de52cc8](https://github.com/launchdarkly/flutter-client-sdk/commit/de52cc8515337c40b1e1efe3c83994af7df6394e))

## [4.10.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.9.0...4.10.0) (2025-04-18)


### Features

* **deps:** Update minimum required Flutter version to 3.22.0 and minimum required Dart version to 3.4.0 ([#186](https://github.com/launchdarkly/flutter-client-sdk/issues/186)) ([1b36324](https://github.com/launchdarkly/flutter-client-sdk/commit/1b363247ef5d01e08baa480e4f5ed4b644397dad))

## [4.9.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.8.0...4.9.0) (2024-12-13)


### Features

* Support device_info_plus version 11. ([#180](https://github.com/launchdarkly/flutter-client-sdk/issues/180)) ([24e0ca2](https://github.com/launchdarkly/flutter-client-sdk/commit/24e0ca2f124032bc3b4bd39420fac66d7fb9cc59))

## [4.8.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.7.1...4.8.0) (2024-10-31)


### Features

* Adds support for client-side prerequisite events ([#177](https://github.com/launchdarkly/flutter-client-sdk/issues/177)) ([dea28fd](https://github.com/launchdarkly/flutter-client-sdk/commit/dea28fda80fedd8a16e5791990725c2d77c8fa5c))

## [4.7.1](https://github.com/launchdarkly/flutter-client-sdk/compare/4.7.0...4.7.1) (2024-10-09)


### Bug Fixes

* Update to common-client 1.3.1 ([#170](https://github.com/launchdarkly/flutter-client-sdk/issues/170)) ([8da99a0](https://github.com/launchdarkly/flutter-client-sdk/commit/8da99a0be1ab80d1298a6bb732f9105d9a738715))

## [4.7.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.6.0...4.7.0) (2024-08-01)


### Features

* Add support for waiting for non-cached values. ([#160](https://github.com/launchdarkly/flutter-client-sdk/issues/160)) ([28f7efa](https://github.com/launchdarkly/flutter-client-sdk/commit/28f7efa6128b937a4626fe4b4ca60b9e64db1641))
* Update to common client 1.3.0 ([#164](https://github.com/launchdarkly/flutter-client-sdk/issues/164)) ([3189d51](https://github.com/launchdarkly/flutter-client-sdk/commit/3189d51d938786dddce487a3a638a3465b0c4cc8))

## [4.6.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.5.0...4.6.0) (2024-05-02)


### Features

* Support package_info_plus 8. ([#157](https://github.com/launchdarkly/flutter-client-sdk/issues/157)) ([89d6a55](https://github.com/launchdarkly/flutter-client-sdk/commit/89d6a559f962b5337faf05e4fd2dbd9c03fddf58))

## [4.5.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.4.0...4.5.0) (2024-04-23)


### Features

* Support package_info_plus 7.x ([#154](https://github.com/launchdarkly/flutter-client-sdk/issues/154)) ([4218955](https://github.com/launchdarkly/flutter-client-sdk/commit/42189553e42d8b11902ddc7c8efa63ef90ac3263))

## [4.4.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.3.0...4.4.0) (2024-03-27)


### Features

* Support latest versions of the plus plugins. ([#148](https://github.com/launchdarkly/flutter-client-sdk/issues/148)) ([98dbbed](https://github.com/launchdarkly/flutter-client-sdk/commit/98dbbedabda14a04a761e6b17f3af24f9efeebd3))

## [4.3.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.2.0...4.3.0) (2024-03-18)


### Features

* Update flutter-client to use common-client 1.2.0 ([#146](https://github.com/launchdarkly/flutter-client-sdk/issues/146)) ([0746d4a](https://github.com/launchdarkly/flutter-client-sdk/commit/0746d4a29edb412554f06f76719526c0dc195f8e))

## [4.2.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.1.0...4.2.0) (2024-03-07)


### Features

* Update to use common client 1.1.0 ([#140](https://github.com/launchdarkly/flutter-client-sdk/issues/140)) ([739a6b3](https://github.com/launchdarkly/flutter-client-sdk/commit/739a6b3965ad3aa5cb39db9c5075a8f1abd93693))

## [4.1.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.0.3...4.1.0) (2024-02-15)


### Features

* web based applications will now flush events before closing to ensure events are sent ([#129](https://github.com/launchdarkly/flutter-client-sdk/issues/129)) ([c1e2828](https://github.com/launchdarkly/flutter-client-sdk/commit/c1e2828be64277957760bed08d10a8809dd9e275))


### Bug Fixes

* backgrounded and offline apps no longer attempt to send events ([#130](https://github.com/launchdarkly/flutter-client-sdk/issues/130)) ([f8244ab](https://github.com/launchdarkly/flutter-client-sdk/commit/f8244ab3edefd1951ff07f7c26838faced44fe9a))

## [4.0.3](https://github.com/launchdarkly/flutter-client-sdk/compare/4.0.2...4.0.3) (2024-01-31)


### Bug Fixes

* Decrease package_info_plus version requirements. ([#126](https://github.com/launchdarkly/flutter-client-sdk/issues/126)) ([2e650e5](https://github.com/launchdarkly/flutter-client-sdk/commit/2e650e52fcb6f298e186afdbb507e8c8e436da66))

## [4.0.2](https://github.com/launchdarkly/flutter-client-sdk/compare/4.0.1...4.0.2) (2024-01-31)


### Bug Fixes

* Change LDAttributesBuilder visibility. ([#123](https://github.com/launchdarkly/flutter-client-sdk/issues/123)) ([e25803a](https://github.com/launchdarkly/flutter-client-sdk/commit/e25803a8dc15a7256cd1c896511bdaac51ebf67d))
* Correct API docs link. ([#121](https://github.com/launchdarkly/flutter-client-sdk/issues/121)) ([2c02520](https://github.com/launchdarkly/flutter-client-sdk/commit/2c025204ce3d5cade011f668c37d76f79bef0456))

## [4.0.1](https://github.com/launchdarkly/flutter-client-sdk/compare/4.0.0...4.0.1) (2024-01-31)


### Bug Fixes

* Remove beta notice. Improve publishing. ([#118](https://github.com/launchdarkly/flutter-client-sdk/issues/118)) ([ccd1b28](https://github.com/launchdarkly/flutter-client-sdk/commit/ccd1b284a9203c8bf9db006792338b2cf7facc36))

## [4.0.0](https://github.com/launchdarkly/flutter-client-sdk/compare/4.0.0-alpha.1...4.0.0) (2024-01-31)

This version of the SDK has been re-written in dart and now supports Android, iOS, Windows, macOS, Linux, and Web.

The previous versions were wrappers which utilized our native Android and iOS SDKs.

A migration guide will be available in our [docs](https://docs.launchdarkly.com/sdk/client-side/flutter).

### Features

* Add example project. ([#93](https://github.com/launchdarkly/flutter-client-sdk/issues/93)) ([588ae01](https://github.com/launchdarkly/flutter-client-sdk/commit/588ae0179871c470442ab9ec2d6c03a1754f103e))
* Implement support for REPORT for streaming. ([#96](https://github.com/launchdarkly/flutter-client-sdk/issues/96)) ([1de6079](https://github.com/launchdarkly/flutter-client-sdk/commit/1de60797e2edaac2fdf38f829ee4e3f15260f963))
* Use version 1.0.1 of common client. ([#115](https://github.com/launchdarkly/flutter-client-sdk/issues/115)) ([cd85c65](https://github.com/launchdarkly/flutter-client-sdk/commit/cd85c653e59c686c2529d840aef83d76183e37c2))


### Bug Fixes

* Check for network state on resume. ([#95](https://github.com/launchdarkly/flutter-client-sdk/issues/95)) ([c1cb489](https://github.com/launchdarkly/flutter-client-sdk/commit/c1cb489eebc212d2021cb6247c91955b77dcc7d0))
* Correct timeout handling in example. ([#97](https://github.com/launchdarkly/flutter-client-sdk/issues/97)) ([dc18529](https://github.com/launchdarkly/flutter-client-sdk/commit/dc18529fb43ae405fb4cf36c7ff3185d105906f3))
* Flutter client should depend only on common client. ([#113](https://github.com/launchdarkly/flutter-client-sdk/issues/113)) ([edfd06d](https://github.com/launchdarkly/flutter-client-sdk/commit/edfd06d24e30915c0608766e5abcc9290aaf6244))
* Mac entitlements. Clarifications. ([#107](https://github.com/launchdarkly/flutter-client-sdk/issues/107)) ([077e9aa](https://github.com/launchdarkly/flutter-client-sdk/commit/077e9aa205731b6166bb78788a9a98f1f238fc2d))

## [4.0.0-alpha.1](https://github.com/launchdarkly/flutter-client-sdk/compare/v4.0.0-alpha.0...4.0.0-alpha.1) (2024-01-24)


### Features

* Update common client dependenct to 0.1.0 ([#89](https://github.com/launchdarkly/flutter-client-sdk/issues/89)) ([7dcb687](https://github.com/launchdarkly/flutter-client-sdk/commit/7dcb6876f42c76a6f27df606e281de164d306745))
* Update common/client/event source dependencies. ([#87](https://github.com/launchdarkly/flutter-client-sdk/issues/87)) ([9acbab3](https://github.com/launchdarkly/flutter-client-sdk/commit/9acbab3bbe3ca9a1c63923ea4c95f0eb0dd1177b))


### Bug Fixes

* Fix sink not closed lint. ([#66](https://github.com/launchdarkly/flutter-client-sdk/issues/66)) ([051fd9c](https://github.com/launchdarkly/flutter-client-sdk/commit/051fd9cfc405f23e0bac64da90b9277ccdf5e188))
* Remove flutter dependency from event source. ([#65](https://github.com/launchdarkly/flutter-client-sdk/issues/65)) ([d557692](https://github.com/launchdarkly/flutter-client-sdk/commit/d557692ef7d146a5c691d3b8f64f10726f12add3))

## [4.0.0-alpha.0] - 2024-01-22

Initial 4.0.0 alpha release. 4.0.0 is a re-write of the SDK using Dart instead of native plugins.

## [3.0.1] - 2023-09-21
### Fixed:
- Fixed a rare bug in key generation in some contexts generated by the Auto Environment Attributes feature.

## [3.0.0] - 2023-08-25
### Added:
- Added Automatic Mobile Environment Attributes functionality which makes it simpler to target your mobile customers based on application name or version, or on device characteristics including manufacturer, model, operating system, locale, and so on. To learn more, read [Automatic environment attributes](https://docs.launchdarkly.com/sdk/features/environment-attributes).

### Removed:
- Removed LDUser and related functionality. Use LDContext instead. To learn more, read https://docs.launchdarkly.com/home/contexts.

## [2.1.0] - 2023-08-17
### Changed:
- Deprecated LDUser and related functionality. Use LDContext instead. To learn more, read about [contexts](https://docs.launchdarkly.com/home/contexts).

## [2.0.3] - 2023-08-09
### Fixed:
- Fixes evaluation detail ruleIndex bug affecting iOS

## [2.0.2] - 2023-06-16
### Fixed:
- Fixes threading issue in start routine in Android native code

## [2.0.1] - 2023-06-07
### Fixed:
- Flag listeners are now called correctly after identify results in flag value changes.

## [2.0.0] - 2023-04-26
The latest version of this SDK supports LaunchDarkly's new custom contexts feature. Contexts are an evolution of a previously-existing concept, "users." Contexts let you create targeting rules for feature flags based on a variety of different information, including attributes pertaining to users, organizations, devices, and more. You can even combine contexts to create "multi-contexts."

For detailed information about this version, please refer to the list below. For information on how to upgrade from the previous version, please read the [migration guide](https://docs.launchdarkly.com/sdk/client-side/flutter/migration-1-to-2).

### Added:
- The type `LDContext` and associated builders which define the new context model.
- For SDK methods that took an `LDUser` parameter, there is now an overload (ex: `startWithContext`) that takes an `LDContext`. The SDK still supports `LDUser` for now, but `LDContext` is the preferred model and `LDUser` may be removed in a future version.

### Changed:
- The `secondary` attribute which existed in `LDUser` is no longer a supported feature. If you set an attribute with that name in `LDContext`, it will simply be a custom attribute like any other.
- Analytics event data now uses a new JSON schema due to differences between the context model and the old user model.
- The SDK no longer adds `device` and `os` values to the user attributes. Applications that wish to use device/OS information in feature flag rules must explicitly add such information.
- `maxCachedUsers` is now `maxCachedContexts`
- `LDConfig.privateAttributeNames` is now `privateAttributes`

### Removed:
- Removed the `secondary` meta-attribute in `LDUser` and `LDUser.Builder`.
- The `alias` method no longer exists because alias events are not needed in the new context model.
- The `inlineUsersInEvents` option no longer exists because it is not relevant in the new context model.

## [1.3.0] - 2023-04-04
### Added:
- `LDConfigBuilder.applicationInfo()` and `.applicationVersion()`, for configuration of application metadata that may be used in LaunchDarkly analytics or other product features. This does not affect feature flag evaluations.

## [1.2.0] - 2022-11-07
### Changed:
- Updated Android SDK version.
- Updated Kotlin plugin version to allow working with new default versions in android studio.
- Raised minimum iOS version to 11, and updated to build with XCode 13.

## [1.1.4] - 2022-08-15
### Changed:
- Update to use android-client-sdk 3.1.6. This release contains fixes related to android ANRs.

## [1.1.3] - 2022-07-26
### Fixed:
- When using the flutter SDK on iOS the `device` and `os` custom attributes would not be populated in the user object. These will now be populated correctly.

## [1.1.2] - 2022-06-23
### Changed:
- Update the example project to a new version of flutter embedding and removed usage of deprecated flutter components.
- Update to use ios-client-sdk V6.
- Updated to work with kotlin 1.7.0.
- String variation return types were optional when they did not need to be. They are now not optional. This could produce warnings where string variations were used previously. Those null checks can now be removed.

### Fixed:
- `identify` calls were blocking and could trigger ANRs. They maintain the same interface, and can be awaited, but now they no longer block the calling thread.

## [1.0.0] - 2021-10-29
First supported release of LaunchDarkly's Flutter SDK. This release contains no SDK code changes from the prior beta release.

### Added:
- Support for LaunchDarkly's internal release tool.

## [0.3.0] - 2021-10-15
This is a breaking beta release. The changelog may not detail all changes between beta releases. The SDK is considered to be an unsupported beta until release 1.0.0.

### Added
- `LDClient.startFuture` which can be used to get a `Future` that completes when the SDK has received the most recent flag values for the configured user after starting.
- `LDClient.isInitialized` which can be used to determine whether the SDK has has received the most recent flag values after starting.
- Added the ability to configure the limit to the number of users to cache the flag values for on device. This limit can be configured with `LDConfigBuilder.maxCachedUsers`.

### Changed
- `LDConfigBuilder` setters have had the `set` prefix removed, e.g. `LDConfigBuilder.setOffline` has become `LDConfigBuilder.offline`.
- `LDClient.isOnline` has been replaced with `LDClient.isOffline` for consistency with other LaunchDarkly SDKs.

## [0.2.0] - 2021-09-24
This is a breaking beta release. The changelog may not detail all changes between beta releases. The SDK is considered to be an unsupported beta until release 1.0.0.

### Added
- Added the `alias` method to `LDClient`. This can be used to associate two user objects for analytics purposes with an alias event.
- Added the `autoAliasingOptOut` configuration option. This can be used to control the new automatic aliasing behavior of the `identify` method; by setting `autoAliasingOptOut` to `true`. `identify` will not automatically generate alias events.
- The SDK now supports the ability to control the proportion of traffic allocation to an experiment. This works in conjunction with a new platform feature now available to early access customers.

### Changed
- The SDK implementation is now null-safe.
- The minimum Flutter version has been raised to 2.0.0.
- The minimum Dart version has been raised to 2.12.0.
- The minimum supported Android API version has changed from 16 to 21.
- The underlying SDK on Android has been updated to 3.1.1 from 2.13.0. See the [Android SDK changelog](https://github.com/launchdarkly/android-client-sdk/releases) for details on improvements.
- The underlying SDK on iOS has been updated from 5.2.0 to 5.4.3. See the [iOS SDK changelog](https://github.com/launchdarkly/ios-client-sdk/releases) for details on improvements.
- The `identify` method will now automatically generate an alias event when switching from an anonymous to a known user. This event associates the two users for analytics purposes as they most likely represent a single person.

## [0.1.0] - 2020-10-29
This is the first public release of the LaunchDarkly Flutter client-side SDK. The SDK is considered to be an unsupported beta until release 1.0.0.

### Added
- Support for configuring and initializing a SDK instance.
- Flag evaluation with and without details.
- Retrieving all flag values for the current user.
- Switching users with `identify`.
- Flag change listeners and flags received listeners.
