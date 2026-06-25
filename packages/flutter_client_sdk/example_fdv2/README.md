# LaunchDarkly FDv2 Demo

A manual testing app for the FDv2 data system in the Flutter client SDK.

## What it demonstrates

- Opting into the FDv2 protocol with `dataSystem: DataSystemConfig()`.
- Live flag updates over the FDv2 streaming synchronizer, including the
  polling initializer that runs first.
- Switching connection modes (streaming, polling, offline) at runtime via
  `LDClient.setConnectionMode`.
- Identifying new contexts and watching flag data refresh.
- The data source status (valid, interrupted, offline, ...) as it changes.

## Running

From the repository root, link the workspace packages first:

```
melos bootstrap
```

Then run with your credentials provided through the environment:

```
cd packages/flutter_client_sdk/example_fdv2
flutter run --dart-define LAUNCHDARKLY_MOBILE_KEY=<my-mobile-key>
```

On web, use a client-side ID instead:

```
flutter run --dart-define LAUNCHDARKLY_CLIENT_SIDE_ID=<my-client-side-id> -d chrome
```

Flip a flag in the LaunchDarkly dashboard and the value and "All flags"
sections update in place. Switch to polling and the update arrives on the
next poll; switch to offline and updates stop until you go back online.
