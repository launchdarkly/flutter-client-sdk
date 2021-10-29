#!/bin/bash

set -e

pushd example
flutter build apk --debug
flutter build ios --simulator
popd
