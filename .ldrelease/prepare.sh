#!/bin/bash

set -e

# Setup PATH
echo 'export PATH="$PATH:/usr/local/share/android-sdk/tools/bin"' >> $BASH_ENV
echo 'export PATH="$PATH:/usr/local/share/android-sdk/platform-tools"' >> $BASH_ENV
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> $BASH_ENV

# Install Android SDK, Flutter, and dartdoc
HOMEBREW_NO_AUTO_UPDATE=1 brew tap homebrew/cask
HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask homebrew/cask-versions/adoptopenjdk8
HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask android-sdk
yes | sdkmanager "platform-tools" | grep -v = || true
HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask flutter
flutter upgrade
dart pub global activate dartdoc

# Acknowledge Android licenses
sudo mkdir -p /usr/local/android-sdk-linux/licenses
