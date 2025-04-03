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
  dart --version | awk '{print $4}' | cut -d'.' -f1-3
}

# Function to install Dart SDK
install_dart_sdk() {
  local version=${1:-"stable"} 
  echo "Installing Dart SDK ($version)..."
  
  case "$(uname -m)" in
    x86_64) arch="x64";;
    arm64|aarch64) arch="arm64";;
    *) error "Unsupported architecture"; exit 1;;
  esac

  if [[ "$OS" == "linux" ]]; then
    sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
    sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
    sudo apt-get update
    sudo apt-get install dart
  else
    local base_url="https://storage.googleapis.com/dart-archive/channels"
    curl -OL "${base_url}/${version}/release/latest/sdk/dartsdk-${OS}-${arch}-release.zip"
    unzip "dartsdk-${OS}-${arch}-release.zip"
    export PATH="$PWD/dart-sdk/bin:$PATH"
  fi
  
  dart --version || error "Installation failed"
}

# Function to install Dart dependencies (dart clean + dart pub get)
install_dart_dependencies() {
  local timeout=300
  echo "Installing Dart dependencies..."
  (
    cd "$BUILD_DIR" || exit 1
    timeout $timeout dart pub get || {
      error "Dependency installation timed out"
      exit 1
    }
  )
}

# Function to check if dependencies are up to date
check_dart_dependencies() {
  echo "Checking Dart dependencies..."
  dart pub outdated || {
    warning "Some dependencies are outdated"
    return 1 
  }
  
  # 
  if dart pub audit; then
    echo "No dependency vulnerabilities found"
  fi
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
  echo "=== Dart Environment ==="
  echo "Version: $(dart --version 2>&1)"
  echo "Pub Cache: $(dart pub cache list | wc -l) packages"
  echo "SDK Path: $(which dart)"
  echo "Flutter Compat: $(dart --version | grep -q 'Flutter' && echo 'Yes' || echo 'No')"
  echo "Environment:"
  env | grep -i 'DART\|PUB' | sort
}

# Function to clean cache
clean_dart_cache() {
  echo "Cleaning Dart cache..."
  dart pub cache clean
  rm -rf ~/.pub-cache/{git,hosted}/*
}

