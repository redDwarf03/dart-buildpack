#!/usr/bin/env bash

# shellcheck source=lib/vendor/stdlib_v7.sh
source "$BP_DIR/lib/vendor/stdlib_v7.sh"

# Key-Value Store functions for the buildpack
# This file contains functions for managing a simple key-value store

# @description Initializes a new key-value store
# @param {string} store_path - Path to the store file
# @return {number} 0 if successful, 1 if failed
init_store() {
  local store_path="$1"
  if [ ! -f "$store_path" ]; then
    mkdir -p "$(dirname "$store_path")"
    echo "{}" > "$store_path"
  fi
  if [ -f "$store_path" ] && [ -r "$store_path" ] && [ -w "$store_path" ]; then
    return 0
  fi
  return 1
}

# @description Sets a value in the store
# @param {string} store_path - Path to the store file
# @param {string} key - Key to set
# @param {string} value - Value to store
# @return {number} 0 if successful, 1 if failed
set_value() {
  local store_path="$1"
  local key="$2"
  local value="$3"
  
  if [ ! -f "$store_path" ]; then
    init_store "$store_path"
  fi
  
  local temp_file="$store_path.tmp"
  jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$store_path" > "$temp_file" && mv "$temp_file" "$store_path"
}

# @description Gets a value from the store
# @param {string} store_path - Path to the store file
# @param {string} key - Key to retrieve
# @return {string} The value if found, empty string if not found
get_value() {
  local store_path="$1"
  local key="$2"
  
  if [ ! -f "$store_path" ]; then
    echo ""
    return 1
  fi
  
  local value
  value=$(jq -r --arg k "$key" '.[$k] // empty' "$store_path")
  echo "$value"
}

# @description Deletes a key from the store
# @param {string} store_path - Path to the store file
# @param {string} key - Key to delete
# @return {number} 0 if successful, 1 if failed
delete_value() {
  local store_path="$1"
  local key="$2"
  
  if [ ! -f "$store_path" ]; then
    return 1
  fi
  
  local temp_file="$store_path.tmp"
  jq --arg k "$key" 'del(.[$k])' "$store_path" > "$temp_file" && mv "$temp_file" "$store_path"
}

# @description Lists all keys in the store
# @param {string} store_path - Path to the store file
# @return {string} JSON array of keys
list_keys() {
  local store_path="$1"
  
  if [ ! -f "$store_path" ]; then
    echo "[]"
    return 1
  fi
  
  jq -r 'keys' "$store_path"
}

# @description Checks if a key exists in the store
# @param {string} store_path - Path to the store file
# @param {string} key - Key to check
# @return {number} 0 if exists, 1 if not
has_key() {
  local store_path="$1"
  local key="$2"
  
  if [ ! -f "$store_path" ]; then
    return 1
  fi
  
  local value
  value=$(get_value "$store_path" "$key")
  [ -n "$value" ]
}

# @description Clears all entries from the store
# @param {string} store_path - Path to the store file
# @return {number} 0 if successful, 1 if failed
clear_store() {
  local store_path="$1"
  echo "{}" > "$store_path"
}

# @description Gets the size of the store in bytes
# @param {string} store_path - Path to the store file
# @return {number} Size in bytes
get_store_size() {
  local store_path="$1"
  
  if [ ! -f "$store_path" ]; then
    echo "0"
    return 1
  fi
  
  stat -f%z "$store_path"
}

# Initialize key-value store
kvstore_init() {
  local store_dir="$1"
  
  if [ ! -d "$store_dir" ]; then
    mkdir -p "$store_dir"
  fi
}

# @description Sets a value in the key-value store
# @param {string} store_dir - Directory where the store is located
# @param {string} key - Key to set
# @param {string} value - Value to set
# @return {number} 0 if successful, 1 if failed
kvstore_set() {
  local store_dir="$1"
  local key="$2"
  local value="$3"
  
  kvstore_init "$store_dir"
  
  echo "$value" > "$store_dir/$key"
}

# @description Gets a value from the key-value store
# @param {string} store_dir - Directory where the store is located
# @param {string} key - Key to get
# @return {string} The value if found, empty string if not found
kvstore_get() {
  local store_dir="$1"
  local key="$2"
  
  if [ -f "$store_dir/$key" ]; then
    cat "$store_dir/$key"
  else
    echo ""
  fi
}

# @description Deletes a value from the key-value store
# @param {string} store_dir - Directory where the store is located
# @param {string} key - Key to delete
# @return {number} 0 if successful, 1 if failed
kvstore_delete() {
  local store_dir="$1"
  local key="$2"
  
  if [ -f "$store_dir/$key" ]; then
    rm "$store_dir/$key"
  fi
}

# @description Lists all keys in the key-value store
# @param {string} store_dir - Directory where the store is located
# @return {string} List of keys, one per line
kvstore_keys() {
  local store_dir="$1"
  
  if [ -d "$store_dir" ]; then
    ls -1 "$store_dir"
  fi
}

# @description Checks if a key exists in the key-value store
# @param {string} store_dir - Directory where the store is located
# @param {string} key - Key to check
# @return {number} 0 if key exists, 1 if not
kvstore_exists() {
  local store_dir="$1"
  local key="$2"
  
  if [ -f "$store_dir/$key" ]; then
    return 0
  fi
  return 1
}

# @description Clears all values from the key-value store
# @param {string} store_dir - Directory where the store is located
# @return {number} 0 if successful, 1 if failed
kvstore_clear() {
  local store_dir="$1"
  
  if [ -d "$store_dir" ]; then
    rm -rf "$store_dir"/*
  fi
}

# @description Gets the size of the key-value store
# @param {string} store_dir - Directory where the store is located
# @return {number} Size in bytes
kvstore_size() {
  local store_dir="$1"
  
  if [ -d "$store_dir" ]; then
    du -sb "$store_dir" | cut -f1
  else
    echo "0"
  fi
}

# Dart-specific functions
kvstore_set_dart_version() {
  local store_dir="$1"
  local version="$2"
  kvstore_set "$store_dir" "dart_version" "$version"
}

kvstore_get_dart_version() {
  local store_dir="$1"
  kvstore_get "$store_dir" "dart_version"
}

kvstore_set_package_name() {
  local store_dir="$1"
  local name="$2"
  kvstore_set "$store_dir" "package_name" "$name"
}

kvstore_get_package_name() {
  local store_dir="$1"
  kvstore_get "$store_dir" "package_name"
}

kvstore_set_package_version() {
  local store_dir="$1"
  local version="$2"
  kvstore_set "$store_dir" "package_version" "$version"
}

kvstore_get_package_version() {
  local store_dir="$1"
  kvstore_get "$store_dir" "package_version"
}

kvstore_set_build_time() {
  local store_dir="$1"
  local time="$2"
  kvstore_set "$store_dir" "build_time" "$time"
}

kvstore_get_build_time() {
  local store_dir="$1"
  kvstore_get "$store_dir" "build_time"
}

kvstore_set_build_status() {
  local store_dir="$1"
  local status="$2"
  kvstore_set "$store_dir" "build_status" "$status"
}

kvstore_get_build_status() {
  local store_dir="$1"
  kvstore_get "$store_dir" "build_status"
}

kvstore_set_cache_status() {
  local store_dir="$1"
  local status="$2"
  kvstore_set "$store_dir" "cache_status" "$status"
}

kvstore_get_cache_status() {
  local store_dir="$1"
  kvstore_get "$store_dir" "cache_status"
}

kvstore_set_dependency_count() {
  local store_dir="$1"
  local count="$2"
  kvstore_set "$store_dir" "dependency_count" "$count"
}

kvstore_get_dependency_count() {
  local store_dir="$1"
  kvstore_get "$store_dir" "dependency_count"
}

kvstore_set_build_mode() {
  local store_dir="$1"
  local mode="$2"
  kvstore_set "$store_dir" "build_mode" "$mode"
}

kvstore_get_build_mode() {
  local store_dir="$1"
  kvstore_get "$store_dir" "build_mode"
}

kvstore_set_build_output() {
  local store_dir="$1"
  local output="$2"
  kvstore_set "$store_dir" "build_output" "$output"
}

kvstore_get_build_output() {
  local store_dir="$1"
  kvstore_get "$store_dir" "build_output"
}

kvstore_set_build_error() {
  local store_dir="$1"
  local error="$2"
  kvstore_set "$store_dir" "build_error" "$error"
}

kvstore_get_build_error() {
  local store_dir="$1"
  kvstore_get "$store_dir" "build_error"
}

kvstore_set_build_warnings() {
  local store_dir="$1"
  local warnings="$2"
  kvstore_set "$store_dir" "build_warnings" "$warnings"
}

kvstore_get_build_warnings() {
  local store_dir="$1"
  kvstore_get "$store_dir" "build_warnings"
}

kvstore_set_build_metrics() {
  local store_dir="$1"
  local metrics="$2"
  kvstore_set "$store_dir" "build_metrics" "$metrics"
}

kvstore_get_build_metrics() {
  local store_dir="$1"
  kvstore_get "$store_dir" "build_metrics"
}
