#!/usr/bin/env bash

# shellcheck source=lib/vendor/stdlib_v7.sh
source "$BP_DIR/lib/vendor/stdlib_v7.sh"
# shellcheck source=lib/kvstore.sh
source "$BP_DIR/lib/kvstore.sh"

# This module is designed to be able to roll out features to a
# random segment of users for A/B testing. This takes as input a
# list of features along with % chance they will be enabled,
# decides which to enable, and persists these decisions into the
# application cache.
#
# This module takes in no outside data, so it is limited in it's
# uses. While a feature can be persisted between builds for the
# same app, it cannot be consistent for a given user / team. Even
# different PR apps will be decided independently.
#
# This means that this should not be used for changing the build 
# behavior of the buildpack. Builds should always work consistently
# no matter what features are turned on or off.
#
# Where this module can be useful is when deciding between two 
# identical behaviors that may have performance trade-offs, or
# testing the efficacy of different messaging. 
#
# Examples: 
#    testing two different caching strategies for pub packages
#    showing guidance on a particular type of failure
#
# It is expected that these features will be used for roll-outs 
# and be short-lived
#
# ** Schema **
#
# This module expects a "schema" file as input. This is used to
# make sure that all current features are documented in one 
# place. The file is a list of key=value pairs on individual 
# lines.
#
# The key is the name, and the value is an integery between 0 and
# 100 inclusive that represents the likelyhood that the feature
# will be turned on for any given app.
#
# Example:
# ```
# dart-aot=100     // this will always be turned on, not super useful
# pub-cache=50     // this will be split 50/50
# analyzer=5       // this will be turned on for 5% of apps
# ```
#
# ** Invalidating features **
#
# Any time the schema file contents change, the existing feature
# assignments will be invalidated and re-assigned
#
# ** Testing **
#
# It would be frustrating if it wasn't clear when CI was running which
# branch was being used, or if tests were flaky because they were choosing
# different features for each run.
#
# To that end, there is a special file that can be included in test fixtures
# to hard-code features to turn on and off.
# 
# $BUILD_DIR/scalingo-buildpack-features
#
# Example:
# ```
# dart-aot=true 
# pub-cache=true 
# ```
#
# An empty file can be included as part of test code to default all tests
# to off
#
# Once a feature is in production, checking this file into your app
# can allow you to choose which features you want an app to use.

# variables shared by this whole module
FEATURES_DATA_FILE=""
OVERRIDE_FILE=""

# Initialize features
features_init() {
  local name="$1"
  local build_dir="$2"
  local cache_dir="$3"
  local features_dir="$4"

  mkdir -p "$features_dir"
  echo "{}" > "$features_dir/features.json"

  # Initialize feature tracking
  meta_set "features" "{}"
  meta_set "buildpack" "$name"
  meta_set "build-dir" "$build_dir"
  meta_set "cache-dir" "$cache_dir"

  local last_schema_hash schema_hash random odds hash_file schema_file store_dir

  store_dir="$cache_dir/features"
  FEATURES_DATA_FILE="$store_dir/$name"
  hash_file="$store_dir/$name-hash"
  OVERRIDE_FILE="$build_dir/scalingo-buildpack-features"
  schema_file="$features_dir/schema"

  mkdir -p "$store_dir"
  touch "$hash_file"

  # Create default schema if it doesn't exist
  if [ ! -f "$schema_file" ]; then
    echo "dart-aot=100" > "$schema_file"
    echo "pub-cache=50" >> "$schema_file"
    echo "analyzer=5" >> "$schema_file"
  fi

  last_schema_hash="$(cat "$hash_file")"
  schema_hash="$(sha1sum "$schema_file" | awk '{ print $1 }')"

  # If the schema has changed, blow away the current values
  # and start fresh. This is essentially "wiping the slate clean"
  # and no previous features will be enabled for anyone
  #
  # In the case that the schema hash is the same, we keep
  # all of the previously decided features (file is the same)
  # and decide on any new ones
  if [[ "$last_schema_hash" != "$schema_hash" ]]; then
    kvstore_init "$store_dir"
    # save out the hash we're using to generate this set of features
    echo "$schema_hash" > "$hash_file"
  fi

  # iterate through the schema and decide if each new feature
  # should be turned on or not
  while IFS='=' read -r key value; do
    if [[ -n "$key" ]]; then
      if [[ -n "$(kvstore_get "$store_dir" "$key")" ]]; then
        continue
      else
        # generate a random number between 0 and 100
        random=$((RANDOM % 100))
        # the value in the schema should be a number between 0 and 100 inclusive
        odds="$value"
        if [[ "$random" -lt "$odds" ]]; then
          kvstore_set "$store_dir" "$key" "true"
        else
          kvstore_set "$store_dir" "$key" "false"
        fi
      fi
    fi
  done < "$schema_file"
}

# Add feature
add_feature() {
  local name="$1"
  local enabled="$2"
  local description="$3"

  local features
  features=$(meta_get "features")
  features=$(echo "$features" | jq --arg name "$name" --arg enabled "$enabled" --arg desc "$description" '. + {($name): {"enabled": ($enabled == "true"), "description": $desc}}')
  meta_set "features" "$features"
}

# Enable feature
enable_feature() {
  local name="$1"
  local features
  features=$(meta_get "features")
  features=$(echo "$features" | jq --arg name "$name" '.[$name].enabled = true')
  meta_set "features" "$features"
}

# Disable feature
disable_feature() {
  local name="$1"
  local features
  features=$(meta_get "features")
  features=$(echo "$features" | jq --arg name "$name" '.[$name].enabled = false')
  meta_set "features" "$features"
}

# Check if feature is enabled
is_feature_enabled() {
  local name="$1"
  local features
  features=$(meta_get "features")
  echo "$features" | jq --arg name "$name" '.[$name].enabled' | grep -q "true"
}

# Get feature description
get_feature_description() {
  local name="$1"
  local features
  features=$(meta_get "features")
  echo "$features" | jq --arg name "$name" -r '.[$name].description'
}

# List all features
list_features() {
  local features
  features=$(meta_get "features")
  echo "$features" | jq -r 'to_entries[] | "\(.key): \(.value.description) [\(if .value.enabled then "enabled" else "disabled" end)]"'
}

# Save features to file
save_features() {
  local features_dir="$1"
  local features
  features=$(meta_get "features")
  echo "$features" > "$features_dir/features.json"
}

# Load features from file
load_features() {
  local features_dir="$1"
  if [ -f "$features_dir/features.json" ]; then
    local features
    features=$(cat "$features_dir/features.json")
    meta_set "features" "$features"
  fi
}

# Initialize default Dart features
init_dart_features() {
  # Core features
  add_feature "dart-sdk" "true" "Dart SDK installation and management"
  add_feature "pub-packages" "true" "Pub package management and caching"
  add_feature "build-tools" "true" "Dart build tools and compilation"

  # Compilation features
  add_feature "dart-aot" "true" "Ahead-of-Time compilation for better performance"
  add_feature "dart-web" "false" "Web compilation support (JavaScript)"
  add_feature "dart-native" "false" "Native compilation support"

  # Development features
  add_feature "dev-tools" "false" "Development tools and debugging support"
  add_feature "hot-reload" "false" "Hot reload support for development"
  add_feature "source-maps" "false" "Source maps generation for debugging"

  # Testing features
  add_feature "testing" "false" "Testing framework support"
  add_feature "coverage" "false" "Code coverage reporting"
  add_feature "test-cache" "true" "Cache test results between builds"

  # Documentation features
  add_feature "docs" "false" "Documentation generation support"
  add_feature "api-docs" "false" "API documentation generation"
  add_feature "readme" "true" "README validation and formatting"

  # Analysis features
  add_feature "analysis" "true" "Code analysis and linting"
  add_feature "strong-mode" "true" "Strong mode analysis"
  add_feature "type-check" "true" "Static type checking"

  # Performance features
  add_feature "performance" "false" "Performance monitoring and profiling"
  add_feature "size-analysis" "true" "Code size analysis"
  add_feature "tree-shaking" "true" "Dead code elimination"

  # Security features
  add_feature "security" "true" "Security scanning and vulnerability detection"
  add_feature "dependency-check" "true" "Dependency vulnerability scanning"
  add_feature "license-check" "true" "License compliance checking"

  # Caching features
  add_feature "pub-cache" "true" "Pub package caching"
  add_feature "build-cache" "true" "Build artifact caching"
  add_feature "analysis-cache" "true" "Analysis results caching"
}

# Check feature requirements
check_feature_requirements() {
  local name="$1"
  local requirements_met=true

  case "$name" in
    "dart-web")
      # Check for web compiler requirements
      if ! command -v dart2js &> /dev/null; then
        requirements_met=false
      fi
      ;;
    "dart-native")
      # Check for native compilation requirements
      if ! command -v dart compile &> /dev/null; then
        requirements_met=false
      fi
      ;;
    "testing")
      # Check for testing framework requirements
      if ! command -v dart test &> /dev/null; then
        requirements_met=false
      fi
      ;;
    "coverage")
      # Check for coverage tool requirements
      if ! command -v dart run coverage:test_with_coverage &> /dev/null; then
        requirements_met=false
      fi
      ;;
    "docs")
      # Check for documentation tool requirements
      if ! command -v dartdoc &> /dev/null; then
        requirements_met=false
      fi
      ;;
    "analysis")
      # Check for analyzer requirements
      if ! command -v dart analyze &> /dev/null; then
        requirements_met=false
      fi
      ;;
  esac

  return "$requirements_met"
}

# Get feature status
get_feature_status() {
  local name="$1"
  if is_feature_enabled "$name"; then
    echo "enabled"
  else
    echo "disabled"
  fi
}

# Get feature metrics
get_feature_metrics() {
  local name="$1"
  local metrics=""

  case "$name" in
    "dart-sdk")
      metrics="version: $(dart --version 2>&1 | head -n1)"
      ;;
    "pub-packages")
      metrics="packages: $(get_dependency_count "$BUILD_DIR")"
      ;;
    "build-tools")
      metrics="build-time: $(meta_time "build-time")"
      ;;
    "analysis")
      metrics="warnings: $(dart analyze --format=json | jq '.issues | length')"
      ;;
    "security")
      metrics="vulnerabilities: $(dart pub audit | grep -c "vulnerability")"
      ;;
  esac

  echo "$metrics"
}

# Export features to environment
export_features() {
  local build_dir="$1"
  local features
  features=$(meta_get "features")

  # Create feature environment file
  mkdir -p "$build_dir/.profile.d"
  echo "$features" | jq -r 'to_entries[] | "export DART_FEATURE_\(.key | ascii_upcase)=\(.value.enabled)"' > "$build_dir/.profile.d/features.sh"
}

# Determine whether an feature is enabled or disabled
# Must call features_init first, otherwise only "false" will be returned
#
# Possible outputs: "true" "false"
features_get() {
  local result
  if [[ -f "$OVERRIDE_FILE" ]]; then
    result=$(kvstore_get "$OVERRIDE_FILE" "$1")
  else
    result=$(kvstore_get "$FEATURES_DATA_FILE" "$1")
  fi
  if [[ "$result" == "true" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

features_get_with_blank() {
  local result
  if [[ -f "$OVERRIDE_FILE" ]]; then
    result=$(kvstore_get "$OVERRIDE_FILE" "$1")
  else
    result=$(kvstore_get "$FEATURES_DATA_FILE" "$1")
  fi
  if [[ "$result" == "true" ]]; then
    echo "true"
  elif [[ "$result" == "false" ]]; then
    echo "false"
  else
    echo ""
  fi
}

# List all features
features_list() {
  if [[ -f "$OVERRIDE_FILE" ]]; then
    kvstore_keys "$OVERRIDE_FILE"
  else
    kvstore_keys "$FEATURES_DATA_FILE"
  fi
}

# Force an feature to be turned on or off
# This is expected to be used during development
features_override() {
  local name="$1"
  local value="$2"

  if [[ "$value" == "true" ]]; then
    kvstore_set "$FEATURES_DATA_FILE" "$name" "true"
  else
    kvstore_set "$FEATURES_DATA_FILE" "$name" "false"
  fi
}
