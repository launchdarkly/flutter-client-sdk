Flutter client contract test server built using [Shelf](https://pub.dev/packages/shelf).

# Running with the Dart SDK

You can run the example with the [Dart SDK](https://dart.dev/get-dart)
like this:

```
$ cd apps/flutter_client_contract_test_service/
$ dart pub get
$ flutter test bin/contract_test_service.dart
Server listening on port 8080
```

# Running the contract test harness

The service only answers requests. The tests come from the
[sdk-test-harness](https://github.com/launchdarkly/sdk-test-harness).
Leave the service running, and run the harness in a second terminal:

```
$ cd apps/flutter_client_contract_test_service/
$ curl -s https://raw.githubusercontent.com/launchdarkly/sdk-test-harness/main/downloader/run.sh \
    | VERSION=v2 PARAMS="-url http://localhost:8080 -debug -status-timeout 100 -stop-service-at-end -skip-from testharness-suppressions.txt" sh
```

This runs the FDv1 tests. To run the FDv2 tests, use `v3` in the URL and set
`VERSION=v3`. The `-stop-service-at-end` option stops the service when the
harness finishes, so start the service again before the next run.
`testharness-suppressions.txt` lists the tests that this service skips.

From the repository root, `melos run client-contract-tests` and
`melos run client-contract-tests-fdv2` do both steps.

# Updating the generated API Classes

If you need to add or modify the OpenAPI yaml files to add or modify functionality, you will then probably need to regenerate the *.openapi.dart and *.openapi.g.dart files.  This can be done by running the following command:

```
dart run build_runner build -v
```

You will also need to patch service_api.openapi.dart by replacing all instances of `Object` vs `dynamic`.  This is due to a bug in the generator implementation.