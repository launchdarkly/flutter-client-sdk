# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

This is a [Melos](https://github.com/invertase/melos)-managed Dart/Flutter monorepo that publishes `launchdarkly_flutter_client_sdk` along with its supporting packages.

- `packages/common` (`launchdarkly_dart_common`) — Dart-only code usable by both client-side and server-side SDKs (contexts, `LDValue`, logging, events, env reporting, serialization, network helpers).
- `packages/common_client` (`launchdarkly_common_client`) — client-side SDK code that is not Flutter-specific (flag manager, data sources, hooks, plugins, persistence interface, `LDCommonClient`).
- `packages/event_source_client` (`launchdarkly_event_source_client`) — SSE client implementation used by the streaming data source.
- `packages/flutter_client_sdk` (`launchdarkly_flutter_client_sdk`) — the published Flutter SDK. Wraps `LDCommonClient` and provides Flutter-specific `Persistence` (`shared_preferences`), env reporter (`package_info_plus`/`device_info_plus`), state detection (`connectivity_plus` + lifecycle), and a `ConnectionManager`.
- `apps/sse_contract_test_service` and `apps/flutter_client_contract_test_service` — test service harnesses driven by LaunchDarkly's centralized contract test runners.
- `architechture/` — Mermaid diagrams describing high-level architecture and the `identify` flow. Note the misspelling of the directory.

Inter-package dependencies are pinned to exact versions in `pubspec.yaml` files. See `RELEASING.md`: a change to `common` requires a release-in-dependency-order (common → common_client → flutter_client_sdk), with a manual PR between each release to bump the pinned version.

## Common commands

All commands are run from the repo root and go through Melos.

```
dart pub global activate melos          # one-time
melos bootstrap                          # install deps for every package
melos run analyze                        # dart analyze --fatal-infos across all packages
melos run fix                            # dart fix --apply
melos run test                           # runs `flutter test --coverage` in common, common_client, flutter_client_sdk
melos run sse-contract-tests             # start SSE contract service and run the v2 harness
melos run client-contract-tests          # start Flutter client contract service and run the SDK harness
melos run coverage-report                # merge lcov files and show coverage value (requires `dart pub global activate coverde`)
melos run coverage-report-html           # same, but emits HTML to coverage/html/
melos run launchdarkly_flutter_example   # build/run the example app for manual testing
```

To run a single test file, cd into the package and use Flutter directly, e.g. `cd packages/common_client && flutter test test/path/to/file_test.dart`. The `melos run test` target only covers `launchdarkly_dart_common`, `launchdarkly_common_client`, and `launchdarkly_flutter_client_sdk` — `event_source_client` tests are not yet wired in.

## Architecture

The Flutter SDK is a thin adapter layer around `LDCommonClient` (in `common_client`). `LDClient` in `packages/flutter_client_sdk/lib/src/ld_client.dart` constructs a `CommonPlatform` with platform-specific implementations and delegates flag evaluation, identify, events, and data source management to the common client.

Key collaborators inside `LDCommonClient`:

- **FlagManager** owns `FlagStore` (in-memory flag cache), `FlagUpdater` (emits `FlagsChangedEvent`s), and `FlagPersistence` (writes through to a `Persistence` implementation).
- **DataSourceManager** selects between `StreamingDataSource` (SSE, via `event_source_client`) and `PollingDataSource` based on `ConnectionMode`, and routes updates through `DataSourceEventHandler` into the `FlagManager`.
- **Context modifiers** (anonymous key generation, auto-env attributes) mutate the inbound `LDContext` before evaluation.
- **Hooks** and **plugins** wrap variation/identify/track calls; plugins can also contribute hooks (see `safeGetHooks` + `combineHooks` used by `LDClient`).

Flutter-specific additions layered on top:

- `SharedPreferencesPersistence` implements the `Persistence` interface.
- `PlatformEnvReporter` implements `EnvironmentReporter` using `package_info_plus` / `device_info_plus`.
- `FlutterStateDetector` combines `connectivity_plus` with app lifecycle events to feed the `ConnectionManager`, which switches `ConnectionMode` (streaming / polling / offline) based on foreground/background and network state.

See `architechture/high_level.md` for the class diagram and `architechture/identify.md` for the identify sequence.

## Conventions

- Follow `common_analysis.yaml`: relative imports inside a package's `lib/`, single quotes, explicit return types, and close your `StreamSink`s.
- Code changes use Conventional Commits (`feat:`, `fix:`, `chore:`, …). Release PRs are produced by release-please and the flow is described in `RELEASING.md`. The SDK version string in `packages/flutter_client_sdk/lib/src/ld_client.dart` carries a `// x-release-please-version` marker — do not edit it manually.
- Public API from `common` and `common_client` is re-exported through `packages/common_client/lib/launchdarkly_common_client.dart`; when adding new public types, add them to that export list so the Flutter package can surface them.
