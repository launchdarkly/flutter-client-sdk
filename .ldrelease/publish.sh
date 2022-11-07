#!/bin/bash

set -e

# Copy secret to allow publishing
if [ -z "${XDG_CONFIG_HOME:-}" ]; then
	# Linux with XDG_CONFIG_HOME defined.
	mkdir -p $XDG_CONFIG_HOME/dart
	mv $LD_RELEASE_SECRETS_DIR/pub_creds $XDG_CONFIG_HOME/dart/pub-credentials.json
elif [ "$(uname)" == "Darwin" ]; then
	# Mac
	mkdir -p ~/Library/Application Support/dart/
	mv $LD_RELEASE_SECRETS_DIR/pub_creds ~/Library/Application Support/dart/pub-credentials.json
else
	# Linux without XDG_CONFIG_HOME defined.
	mkdir -p ~/.config/dart
	mv $LD_RELEASE_SECRETS_DIR/pub_creds ~/.config/dart/pub-credentials.json
fi

flutter pub publish -f
