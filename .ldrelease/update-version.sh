#!/bin/bash

set -e

TEMP_FILE=`mktemp -u` || exit 1

sed "s/^version: [0-9.]*$/version: ${LD_RELEASE_VERSION}/" 'pubspec.yaml' > $TEMP_FILE
mv $TEMP_FILE 'pubspec.yaml'

DART_PATTERN="s/const String _sdkVersion = \"[0-9.]*\"\;$/const String _sdkVersion = \"${LD_RELEASE_VERSION}\"\;/"
sed "${DART_PATTERN}" 'lib/launchdarkly_flutter_client_sdk.dart' > $TEMP_FILE
mv $TEMP_FILE 'lib/launchdarkly_flutter_client_sdk.dart'

sed "${DART_PATTERN}" 'test/launchdarkly_flutter_client_sdk_test.dart' > $TEMP_FILE
mv $TEMP_FILE 'test/launchdarkly_flutter_client_sdk_test.dart'
