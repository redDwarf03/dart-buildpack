#!/usr/bin/env bash

# Shared variables for managing build metadata
BUILD_DATA_FILE=""
PREVIOUS_BUILD_DATA_FILE=""

# Must be called before any other methods can be used
meta_init() {
  local cache_dir="$1"
  BUILD_DATA_FILE="$cache_dir/build-data/dart"
  PREVIOUS_BUILD_DATA_FILE="$cache_dir/build-data/dart-prev"
}

# Moves the data from the last build into the correct place, and clears the store
# This should be called after meta_init in bin/compile
meta_setup() {
  # if the file already exists from the last build, save it
  if [[ -f "$BUILD_DATA_FILE" ]]; then
    cp "$BUILD_DATA_FILE" "$PREVIOUS_BUILD_DATA_FILE"
  fi

  kv_create "$BUILD_DATA_FILE"
  kv_clear "$BUILD_DATA_FILE"
}

# Force removal of existing data files. This is mainly for testing purposes and not expected to be used during actual builds.
meta_force_clear() {
  [[ -f "$BUILD_DATA_FILE" ]] && rm "$BUILD_DATA_FILE"
  [[ -f "$PREVIOUS_BUILD_DATA_FILE" ]] && rm "$PREVIOUS_BUILD_DATA_FILE"
}

# Get a value from the current build's metadata
meta_get() {
  kv_get "$BUILD_DATA_FILE" "$1"
}

# Set a key-value pair in the current build's metadata
meta_set() {
  kv_set "$BUILD_DATA_FILE" "$1" "$2"
}

# Similar to mtime from standard libraries
meta_time() {
  local key="$1"
  local start="$2"
  local end="${3:-$(nowms)}"
  local time
  time="$(echo "${start}" "${end}" | awk '{ printf "%.3f", ($2 - $1)/1000 }')"
  kv_set "$BUILD_DATA_FILE" "$key" "$time"
}

# Retrieve a value from a previous build's metadata, if it exists.
# Useful to give context on changes if the build failed (e.g., stack changes, version updates).
meta_prev_get() {
  kv_get "$PREVIOUS_BUILD_DATA_FILE" "$1"
}

# Log all metadata in a logfmt format (one line output)
log_meta_data() {
  # Print all key-value pairs in logfmt format
  # https://brandur.org/logfmt
  # Ensuring output is on a single line
  echo $(kv_list "$BUILD_DATA_FILE")
}
