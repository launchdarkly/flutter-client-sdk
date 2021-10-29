#!/bin/bash

set -e

# Copy secret to allow publishing
mkdir -p $HOME/.pub-cache
mv $LD_RELEASE_SECRETS_DIR/pub_creds $HOME/.pub-cache/credentials.json

flutter pub publish
