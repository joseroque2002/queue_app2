#!/bin/bash
set -e

# Install Flutter
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:$PWD/flutter/bin"

# Verify Flutter installation
flutter doctor

# Get dependencies
flutter pub get

# Build web app
flutter build web --release