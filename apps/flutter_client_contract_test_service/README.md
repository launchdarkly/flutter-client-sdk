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

# Updating the generated API Classes

If you need to add or modify the OpenAPI yaml files to add or modify functionality, you will then probably need to regenerate the *.openapi.dart and *.openapi.g.dart files.  This can be done by running the following command:

```
dart run build_runner build -v
```

You will also need to patch service_api.openapi.dart by replacing all instances of `Object` vs `dynamic`.  This is due to a bug in the generator implementation.