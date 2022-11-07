#!/bin/bash

set -e

# Download link from: https://docs.flutter.dev/get-started/install/macos
FLUTTER_RELEASE="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.3.7-stable.zip"

# Download Android command line tools
mkdir -p $ANDROID_SDK_ROOT/cmdline-tools/latest

# Download link from: https://developer.android.com/studio
# There should be a "Command line tools only" section on the page.
curl https://dl.google.com/android/repository/commandlinetools-mac-8512546_latest.zip -o cmdline-tools.zip
unzip cmdline-tools.zip
mv cmdline-tools/* $ANDROID_SDK_ROOT/cmdline-tools/latest/
yes | $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null || true

# Install Flutter and dartdoc
cd $HOME
curl $FLUTTER_RELEASE -o flutter.zip
unzip -q flutter.zip
export PATH="$PATH:$HOME/flutter/bin"
dart pub global activate dartdoc

# Setup Flutter PATHs
FLUTTER_PATHS="$HOME/flutter/bin:$HOME/.pub-cache/bin"
echo "export PATH=\"\$PATH:$FLUTTER_PATHS\"" >> $BASH_ENV
