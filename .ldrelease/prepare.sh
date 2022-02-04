#!/bin/bash

set -e

FLUTTER_RELEASE="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_2.8.1-stable.zip"

# Setup Android PATHs
echo 'export PATH="$PATH:/usr/local/share/android-sdk/tools/bin"' >> $BASH_ENV
echo 'export PATH="$PATH:/usr/local/share/android-sdk/platform-tools"' >> $BASH_ENV

# Install Java and Android SDK
brew install --cask temurin8 android-sdk
yes | sdkmanager "platform-tools" | grep -v = || true

# Acknowledge Android licenses
sudo mkdir -p /usr/local/android-sdk-linux/licenses

# Install Flutter and dartdoc
cd $HOME
curl $FLUTTER_RELEASE -o flutter.zip
unzip -q flutter.zip
export PATH="$PATH:$HOME/flutter/bin"
dart pub global activate dartdoc

# Setup Flutter PATHs
FLUTTER_PATHS="$HOME/flutter/bin:$HOME/.pub-cache/bin"
echo "export PATH=\"\$PATH:$FLUTTER_PATHS\"" >> $BASH_ENV
