# Change log

All notable changes to the LaunchDarkly Flutter client-side SDK will be documented in this file. This project adheres to [Semantic Versioning](https://semver.org).

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
