#!/usr/bin/env bash

# Function to measure the size of the "pubspec.lock" file
measure_size() {
  local lock_file="pubspec.lock"
  
  if [[ -f "$lock_file" ]]; then
    echo "The size of the pubspec.lock file is:"
    du -sh "$lock_file" 2>/dev/null || echo 0
  else
    echo "The pubspec.lock file does not exist."
  fi
}

# Function to list the project's dependencies
list_dependencies() {
  local build_dir="$1"
  
  echo "Listing dependencies in $build_dir:"
  cd "$build_dir" || return
  dart pub deps
}

# Function to run a script if it exists in the pubspec.yaml
run_if_present() {
  local build_dir=${1:-}
  local script_name=${2:-}
  
  if [[ -f "$build_dir/pubspec.yaml" ]]; then
    echo "Checking for scripts in pubspec.yaml for script: $script_name"
    # Dart does not natively support custom scripts like some other ecosystems, but you can still run defined commands
    if grep -q "$script_name" "$build_dir/pubspec.yaml"; then
      echo "The script $script_name is defined. Running..."
      # Example: Running a Dart script with the dart run command
      dart run "$script_name"
    else
      echo "The script $script_name does not exist in pubspec.yaml."
    fi
  else
    echo "The pubspec.yaml file does not exist in $build_dir."
  fi
}

# Function to install dependencies for a Dart project
install_dependencies() {
  local build_dir="$1"

  echo "Installing dependencies for Dart in $build_dir..."
  cd "$build_dir" || return
  dart pub get
}

# Function to update the dependencies to the latest compatible versions
update_dependencies() {
  local build_dir="$1"
  
  echo "Updating dependencies in $build_dir..."
  cd "$build_dir" || return
  dart pub upgrade
}

# Function to clean up unused dependencies (Dart does not have a direct pruning command)
clean_dependencies() {
  local build_dir="$1"
  
  echo "Cleaning dependencies in $build_dir..."
  cd "$build_dir" || return
  # Dart doesn't offer a pruning command directly, but we can update dependencies to the latest major versions
  dart pub upgrade --major-versions
}

# Function to check for outdated dependencies
check_outdated_dependencies() {
  local build_dir="$1"
  
  echo "Checking for outdated dependencies in $build_dir..."
  cd "$build_dir" || return
  dart pub outdated
}

# Function to check if a pubspec.yaml file exists
has_pubspec() {
  local build_dir="$1"
  
  if [[ -f "$build_dir/pubspec.yaml" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Example usage of the functions in the script
build_dir="./"  # Replace with your project directory path

# Check if pubspec.yaml exists in the project directory
if [[ "$(has_pubspec "$build_dir")" == "true" ]]; then
  echo "The project contains a pubspec.yaml file."
  
  # Install dependencies
  install_dependencies "$build_dir"
  
  # List dependencies
  list_dependencies "$build_dir"
  
  # Check for outdated dependencies
  check_outdated_dependencies "$build_dir"
  
  # Update dependencies
  update_dependencies "$build_dir"
  
  # Clean dependencies
  clean_dependencies "$build_dir"
else
  echo "The pubspec.yaml file was not found in the $build_dir directory."
fi
