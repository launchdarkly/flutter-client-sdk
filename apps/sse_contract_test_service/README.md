SSE client contract test server built using [Shelf](https://pub.dev/packages/shelf).

# Running with the Dart SDK

You can run the example with the [Dart SDK](https://dart.dev/get-dart)
like this:

```
$ cd sse_contract_test_service
$ dart pub get
$ dart run bin/sse_contract_tests.dart
Server listening on port 8080
```

# Updating the generated API Classes

If you need to add or modify the OpenAPI yaml files to add or modify functionality, you will then probably need to regenerate the *.openapi.dart and *.openapi.g.dart files.  This can be done by running the following command:

```
dart run build_runner build -v
```
