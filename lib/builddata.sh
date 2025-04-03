#!/usr/bin/env bash

# Log out information about the build that we can detect without accessing pubspec.yaml
log_initial_state() {
  meta_set "buildpack" "dart"
  
  # Detect package manager (pub or flutter pub)
  if [[ -f "$BUILD_DIR/pubspec.lock" ]]; then
    if grep -q "flutter:" "$BUILD_DIR/pubspec.yaml"; then
      meta_set "dart-package-manager" "flutter-pub"
    else
      meta_set "dart-package-manager" "dart-pub"
    fi
    meta_set "has-dart-lock-file" "true"
  else
    meta_set "has-dart-lock-file" "false"
  fi

  meta_set "stack" "$STACK"
  meta_set "dart-version" "$(dart --version 2>&1 | head -1)"
  
  # Flutter specific detection
  if command -v flutter &> /dev/null; then
    meta_set "flutter-version" "$(flutter --version 2>&1 | head -1)"
    meta_set "uses-flutter" "true"
  else
    meta_set "uses-flutter" "false"
  fi

  # Add active features to metadata
  # prefix the key with "feature-"
  features_list | tr ' ' '\n' | while read -r key; do
    if [[ -n $key ]]; then
      meta_set "feature-$key" "$(features_get "$key")"
    fi
  done
}

# Log out information about the Dart/Flutter project
log_project_info() {
  local build_dir="$1"
  local time
  time=$(nowms)

  # Basic project metadata
  if [[ -f "$build_dir/pubspec.yaml" ]]; then
    meta_set "has-pubspec" "true"
    
    # Extract basic pubspec info
    meta_set "project-name" "$(yq eval '.name' "$build_dir/pubspec.yaml" 2>/dev/null || echo 'unknown')"
    meta_set "project-version" "$(yq eval '.version' "$build_dir/pubspec.yaml" 2>/dev/null || echo 'unknown')"
    
    # SDK constraints
    meta_set "dart-sdk-constraint" "$(yq eval '.environment.sdk' "$build_dir/pubspec.yaml" 2>/dev/null || echo 'none')"
    meta_set "flutter-constraint" "$(yq eval '.environment.flutter' "$build_dir/pubspec.yaml" 2>/dev/null || echo 'none')"
    
    # Dependencies analysis
    meta_set "num-dependencies" "$(yq eval '.dependencies | length' "$build_dir/pubspec.yaml" 2>/dev/null || echo 0)"
    meta_set "num-dev-dependencies" "$(yq eval '.dev_dependencies | length' "$build_dir/pubspec.yaml" 2>/dev/null || echo 0)"
    
    # Flutter specific
    meta_set "is-flutter-project" "$(yq eval 'has("flutter")' "$build_dir/pubspec.yaml" 2>/dev/null || echo 'false')"
    
    # Build system detection
    meta_set "uses-build-runner" "$(grep -q "build_runner" "$build_dir/pubspec.yaml" && echo "true" || echo "false")"
  else
    meta_set "has-pubspec" "false"
  fi

  # Project structure analysis
  meta_set "has-lib-dir" "$([ -d "$build_dir/lib" ] && echo "true" || echo "false")"
  meta_set "has-test-dir" "$([ -d "$build_dir/test" ] && echo "true" || echo "false")"
  meta_set "has-web-dir" "$([ -d "$build_dir/web" ] && echo "true" || echo "false")"
  meta_set "has-android-dir" "$([ -d "$build_dir/android" ] && echo "true" || echo "false")"
  meta_set "has-ios-dir" "$([ -d "$build_dir/ios" ] && echo "true" || echo "false")"

  # Count project files (excluding build and .dart_tool)
  meta_set "num-dart-files" "$(find "$build_dir" \
    -name '*.dart' \
    -not -path "$build_dir/.dart_tool/*" \
    -not -path "$build_dir/build/*" \
    -not -path "$build_dir/packages/*" \
    | wc -l | tr -d '[:space:]')"

  meta_time "project-analysis-time" "$time"
}

generate_uuids() {
  # generate a unique id for each build
  meta_set "build-uuid" "$(uuid)"

  # propagate an app-uuid forward unless the cache is cleared
  if [[ -n "$(meta_prev_get "app-uuid")" ]]; then
    meta_set "app-uuid" "$(meta_prev_get "app-uuid")"
  else
    meta_set "app-uuid" "$(uuid)"
  fi
}

# Helper function to get current timestamp in milliseconds
nowms() {
  # Use printf to handle large numbers consistently
  printf "%d000" "$(date +%s)"  # Seconds since epoch + milliseconds
}