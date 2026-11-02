Contract test service that runs the Flutter SDK in a browser.

The SDK streams with `SSEClient.http`, not with the browser native
`EventSource`. The native client cannot send a request body or report an HTTP
error. So this service is the only contract test run that covers `usePost` and
HTTP error handling for streaming on web.

# How it works

The contract test harness speaks REST. A browser cannot listen for HTTP
requests. So the service has two parts:

- `bin/adapter.dart` runs on the Dart VM. It serves the REST API for the
  harness, serves the web build, starts headless Chrome, and relays each
  request to the browser over a websocket.
- `lib/main.dart` is a Flutter web app. It runs in the browser, connects to
  the adapter, and runs each request with the SDK.

The browser tells the adapter which capabilities it has when it connects. The
capabilities that depend on the streaming transport (`client-use-post` and
`client-event-source-http-errors`) come from the SSE client in use.

# Running it

You need Chrome. The adapter uses the `CHROME_EXECUTABLE` variable or the
`--chrome` option first. Otherwise it uses the Chrome app on macOS, and
`google-chrome` from your `PATH` on other platforms.

```
$ cd apps/flutter_web_contract_test_service/
$ flutter build web --release --base-href /app/ -t lib/main.dart
$ dart run bin/adapter.dart
Adapter listening on port 8080
Browser connected
```

Leave the adapter running, and run the
[sdk-test-harness](https://github.com/launchdarkly/sdk-test-harness) in a
second terminal:

```
$ cd apps/flutter_web_contract_test_service/
$ curl -s https://raw.githubusercontent.com/launchdarkly/sdk-test-harness/main/downloader/run.sh \
    | VERSION=v2 PARAMS="-url http://localhost:8080 -debug -status-timeout 100 -stop-service-at-end -skip-from testharness-suppressions.txt" sh
```

This runs the FDv1 tests. To run the FDv2 tests, use `v3` in the URL, set
`VERSION=v3`, and skip from `testharness-suppressions-fdv2.txt`. The
`-stop-service-at-end` option stops the adapter when the harness finishes, so
start the adapter again before the next run.

From the repository root, `melos run client-web-contract-tests` (FDv1) and
`melos run client-web-contract-tests-fdv2` (FDv2) build the web app, start the
adapter, and run the harness.

`testharness-suppressions.txt` (FDv1) and `testharness-suppressions-fdv2.txt`
(FDv2) list the harness tests that this service skips. They match the lists of
the JS browser SDK runs that use the fetch based event source.
