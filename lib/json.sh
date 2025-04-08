#!/usr/bin/env bash

# JSON and YAML manipulation functions for the buildpack
# This file contains functions for reading and writing JSON/YAML files

# @description Reads a value from a JSON file using jq
# @param {string} file - Path to the JSON file
# @param {string} query - jq query to extract the value
# @return {string} The extracted value
json::read() {
  local file="$1"
  local query="$2"
  
  if [ ! -f "$file" ]; then
    echo ""
    return 1
  fi
  
  jq -r "$query" < "$file"
}

# @description Writes a value to a JSON file using jq
# @param {string} file - Path to the JSON file
# @param {string} query - jq query to set the value
# @param {string} value - Value to set
# @return {number} 0 if successful, 1 if failed
json::write() {
  local file="$1"
  local query="$2"
  local value="$3"
  
  if [ ! -f "$file" ]; then
    echo "{}" > "$file"
  fi
  
  local temp_file="$file.tmp"
  jq --arg v "$value" "$query = \$v" "$file" > "$temp_file" && mv "$temp_file" "$file"
}

# @description Reads a value from a YAML file using yq
# @param {string} file - Path to the YAML file
# @param {string} query - yq query to extract the value
# @return {string} The extracted value
json::read_yaml() {
  local file="$1"
  local query="$2"
  
  if [ ! -f "$file" ]; then
    echo ""
    return 1
  fi
  
  yq eval "$query" "$file"
}

# @description Writes a value to a YAML file using yq
# @param {string} file - Path to the YAML file
# @param {string} query - yq query to set the value
# @param {string} value - Value to set
# @return {number} 0 if successful, 1 if failed
json::write_yaml() {
  local file="$1"
  local query="$2"
  local value="$3"
  
  if [ ! -f "$file" ]; then
    echo "{}" > "$file"
  fi
  
  local temp_file="$file.tmp"
  yq eval --inplace "$query = \"$value\"" "$file"
}

# @description Converts a JSON file to YAML format
# @param {string} json_file - Path to the JSON file
# @param {string} yaml_file - Path to output YAML file
# @return {number} 0 if successful, 1 if failed
json::json_to_yaml() {
  local json_file="$1"
  local yaml_file="$2"
  
  if [ ! -f "$json_file" ]; then
    return 1
  fi
  
  yq eval -P "$json_file" > "$yaml_file"
}

# @description Converts a YAML file to JSON format
# @param {string} yaml_file - Path to the YAML file
# @param {string} json_file - Path to output JSON file
# @return {number} 0 if successful, 1 if failed
json::yaml_to_json() {
  local yaml_file="$1"
  local json_file="$2"
  
  if [ ! -f "$yaml_file" ]; then
    return 1
  fi
  
  yq eval -j "$yaml_file" > "$json_file"
}

# @description Validates a JSON file
# @param {string} file - Path to the JSON file
# @return {number} 0 if valid, 1 if invalid
json::validate_json() {
  local file="$1"
  
  if [ ! -f "$file" ]; then
    return 1
  fi
  
  jq empty "$file" >/dev/null 2>&1
}

# @description Validates a YAML file
# @param {string} file - Path to the YAML file
# @return {number} 0 if valid, 1 if invalid
json::validate_yaml() {
  local file="$1"
  
  if [ ! -f "$file" ]; then
    return 1
  fi
  
  yq eval "$file" >/dev/null 2>&1
}

# @description Validates a YAML file
# @param {string} file - Path to the YAML file
# @return {number} 0 if valid, 1 if invalid
json::is_valid_yaml() {
  local file="$1"
  local yq_cmd
  
  if [ ! -f "$file" ]; then
    return 1
  fi
  
  # Déterminer la commande yq à utiliser
  case $(uname) in
    Darwin) yq_cmd="$BP_DIR/lib/vendor/yq-darwin";;
    Linux) yq_cmd="$BP_DIR/lib/vendor/yq-linux";;
    *) yq_cmd="yq";;
  esac
  
  # Try to parse the YAML file
  if ! "$yq_cmd" read "$file" > /dev/null 2>&1; then
    return 1
  fi
  
  return 0
}

# Read pubspec.yaml as JSON
json::read_pubspec() {
  local file="$1"
  local key="$2"
  local yq_cmd
  local result

  # Déterminer la commande yq à utiliser
  case $(uname) in
    Darwin) yq_cmd="$BP_DIR/lib/vendor/yq-darwin";;
    Linux) yq_cmd="$BP_DIR/lib/vendor/yq-linux";;
    *) yq_cmd="yq";;
  esac

  if [ ! -f "$file" ]; then
    puts_debug "pubspec.yaml not found: $file"
    return 1
  fi

  # Read value directly from YAML with error handling
  if ! result=$("$yq_cmd" read "$file" "${key#.}" 2>/dev/null); then
    puts_debug "Failed to read from pubspec.yaml: $file"
    return 1
  fi
  
  # Check if the result is null or empty
  if [ "$result" = "null" ] || [ -z "$result" ]; then
    return 1
  fi

  echo "$result"
  return 0
}

# Write pubspec.yaml from JSON
json::write_pubspec() {
  local file="$1"
  local key="$2"
  local value="$3"
  local yq_cmd

  # Déterminer la commande yq à utiliser
  case $(uname) in
    Darwin) yq_cmd="$BP_DIR/lib/vendor/yq-darwin";;
    Linux) yq_cmd="$BP_DIR/lib/vendor/yq-linux";;
    *) yq_cmd="yq";;
  esac

  if [ -f "$file" ]; then
    # Update value directly in YAML
    "$yq_cmd" eval --inplace "$key = \"$value\"" "$file"
  else
    puts_error "pubspec.yaml not found: $file"
    return 1
  fi
}

# Read Dart version from pubspec.yaml
json::read_dart_version() {
  local file="$1"
  json::read_pubspec "$file" ".environment.sdk"
}

# Read package name from pubspec.yaml
json::read_package_name() {
  local file="$1"
  json::read_pubspec "$file" ".name"
}

# Read package version from pubspec.yaml
json::read_package_version() {
  local file="$1"
  json::read_pubspec "$file" ".version"
}

# Read package dependencies from pubspec.yaml
json::read_package_dependencies() {
  local file="$1"
  json::read_pubspec "$file" ".dependencies"
}

# Read package dev_dependencies from pubspec.yaml
json::read_package_dev_dependencies() {
  local file="$1"
  json::read_pubspec "$file" ".dev_dependencies"
}

# Read package environment from pubspec.yaml
json::read_package_environment() {
  local file="$1"
  json::read_pubspec "$file" ".environment"
}

# @description Checks if a JSON file has a specific key
# @param {string} json_file - Path to the JSON file
# @param {string} key - Key to check for
# @return {number} 0 if key exists, 1 if not
json::json_has_key() {
  local json_file="$1"
  local key="$2"
  
  if [ ! -f "$json_file" ]; then
    return 1
  fi
  
  if yq eval ".$key" "$json_file" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# @description Checks if a JSON file is invalid
# @param {string} json_file - Path to the JSON file
# @return {number} 0 if valid, 1 if invalid
json::is_invalid_json_file() {
  local json_file="$1"
  
  if [ ! -f "$json_file" ]; then
    return 1
  fi
  
  if ! yq eval -j "$json_file" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# @description Checks if a key exists in a JSON file
# @param {string} file - Path to the JSON file
# @param {string} key - Key to check
# @return {number} 0 if key exists, 1 if not
json::has_key() {
  local file="$1"
  local key="$2"
  
  if [ ! -f "$file" ]; then
    return 1
  fi
  
  jq --arg k "$key" 'has($k)' "$file" | grep -q "true"
}

# Export functions
export -f json::is_valid_yaml
export -f json::read
export -f json::write
export -f json::read_yaml
export -f json::write_yaml
export -f json::json_to_yaml
export -f json::yaml_to_json
export -f json::validate_json
export -f json::validate_yaml
export -f json::read_pubspec
export -f json::write_pubspec
export -f json::read_dart_version
export -f json::read_package_name
export -f json::read_package_version
export -f json::read_package_dependencies
export -f json::read_package_dev_dependencies
export -f json::read_package_environment
export -f json::json_has_key
export -f json::is_invalid_json_file
export -f json::has_key

