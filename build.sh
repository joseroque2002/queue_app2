#!/bin/bash
set -e

echo "Starting Flutter web build..."

# Download and extract Flutter
echo "Downloading Flutter SDK..."
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.1-stable.tar.xz | tar -xJ

# Add Flutter to PATH
echo "Setting up Flutter PATH..."
export PATH="$PATH:$PWD/flutter/bin"

# Fix git ownership
echo "Configuring git..."
git config --global --add safe.directory "$PWD/flutter"

# Disable analytics
echo "Disabling Flutter analytics..."
flutter config --no-analytics

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Build web app
echo "Building Flutter web app..."
flutter build web --web-renderer canvaskit

echo "Build completed successfully!"