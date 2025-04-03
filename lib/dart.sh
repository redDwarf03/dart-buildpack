#!/bin/bash

# Function to check if Dart is installed
check_dart_installed() {
  if ! command -v dart &> /dev/null; then
    echo "Dart is not installed."
    exit 1
  fi
}

# Function to get Dart version
get_dart_version() {
  dart --version
}

# Function to install Dart SDK
install_dart_sdk() {
  echo "Installing Dart SDK..."
  # Commands to download and install Dart SDK based on platform
  if [[ "$OS" == "darwin" ]]; then
    # MacOS installation commands
    curl -OL https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-macos-x64-release.zip
    unzip dartsdk-macos-x64-release.zip
    export PATH="$PWD/dart-sdk/bin:$PATH"
  elif [[ "$OS" == "linux" ]]; then
    # Linux installation commands
    sudo apt-get install dart
  fi
}

# Function to install Dart dependencies (dart clean + dart pub get)
install_dart_dependencies() {
  echo "Installing Dart dependencies..."
  dart clean
  dart pub get
}

# Function to check if dependencies are up to date
check_dart_dependencies() {
  echo "Checking if Dart dependencies are up to date..."
  dart pub upgrade
}

# Function to set Dart-related environment variables
set_dart_env() {
  echo "Setting Dart environment variables..."
  export DART_HOME="$BP_DIR/dart-sdk"
  export PATH="$DART_HOME/bin:$PATH"
}

# Function to check Dart SDK and dependencies
check_dart_sdk_and_dependencies() {
  check_dart_installed
  get_dart_version
  install_dart_dependencies
  check_dart_dependencies
}

# Function to display helpful info for debugging
dart_info() {
  echo "Dart Info:"
  get_dart_version
  dart --version
  echo "DART_HOME: $DART_HOME"
}
