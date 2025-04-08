#!/usr/bin/env bash

# shellcheck source=lib/vendor/stdlib_v7.sh
source "$BP_DIR/lib/vendor/stdlib_v7.sh"

warnings=$(mktemp -t scalingo-buildpack-dart-XXXX)

# Detect Dart version
detect_dart_version() {
  local build_dir="$1"
  local cache_dir="$2"

  if [ -f "$build_dir/pubspec.yaml" ]; then
    local sdk_constraint
    sdk_constraint=$(yq -r '.environment.sdk' "$build_dir/pubspec.yaml")
    if [ -z "$sdk_constraint" ]; then
      puts_error "No SDK constraint found in pubspec.yaml"
      return 1
    fi
    meta_set "sdk-constraint" "$sdk_constraint" "$cache_dir"
  else
    puts_error "No pubspec.yaml found"
    return 1
  fi
}

# Handle invalid pubspec.yaml
handle_invalid_pubspec() {
  local build_dir="$1"
  local cache_dir="$2"

  if [ ! -f "$build_dir/pubspec.yaml" ]; then
    puts_error "No pubspec.yaml found in the root directory"
    return 1
  fi

  if ! yq -e . "$build_dir/pubspec.yaml" >/dev/null 2>&1; then
    puts_error "Invalid pubspec.yaml format"
    return 1
  fi

  local name
  name=$(yq -r '.name' "$build_dir/pubspec.yaml")
  if [ -z "$name" ]; then
    puts_error "No project name specified in pubspec.yaml"
    return 1
  fi

  local version
  version=$(yq -r '.version' "$build_dir/pubspec.yaml")
  if [ -z "$version" ]; then
    puts_error "No version specified in pubspec.yaml"
    return 1
  fi

  local sdk_constraint
  sdk_constraint=$(yq -r '.environment.sdk' "$build_dir/pubspec.yaml")
  if [ -z "$sdk_constraint" ]; then
    puts_error "No SDK constraint specified in pubspec.yaml"
    return 1
  fi
}

# Handle compilation failures
handle_compilation_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Compilation failed: $error"
  meta_set "compilation-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Handle dependency failures
handle_dependency_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Dependency resolution failed: $error"
  meta_set "dependency-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Handle test failures
handle_test_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Tests failed: $error"
  meta_set "test-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Handle analysis failures
handle_analysis_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Code analysis failed: $error"
  meta_set "analysis-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Handle build runner failures
handle_build_runner_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Build runner failed: $error"
  meta_set "build-runner-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Handle cache failures
handle_cache_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Cache operation failed: $error"
  meta_set "cache-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Handle environment failures
handle_environment_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Environment setup failed: $error"
  meta_set "environment-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Handle feature failures
handle_feature_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Feature setup failed: $error"
  meta_set "feature-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Handle metadata failures
handle_metadata_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Metadata operation failed: $error"
  meta_set "metadata-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Handle build data failures
handle_build_data_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Build data operation failed: $error"
  meta_set "build-data-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Handle unknown failures
handle_unknown_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error="$3"

  puts_error "Unknown error occurred: $error"
  meta_set "unknown-error" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
  return 1
}

# Get failure message
get_failure_message() {
  local cache_dir="$1"
  local error_type="$2"

  case "$error_type" in
    "compilation")
      meta_get "compilation-error" "$cache_dir"
      ;;
    "dependency")
      meta_get "dependency-error" "$cache_dir"
      ;;
    "test")
      meta_get "test-error" "$cache_dir"
      ;;
    "analysis")
      meta_get "analysis-error" "$cache_dir"
      ;;
    "build-runner")
      meta_get "build-runner-error" "$cache_dir"
      ;;
    "cache")
      meta_get "cache-error" "$cache_dir"
      ;;
    "environment")
      meta_get "environment-error" "$cache_dir"
      ;;
    "feature")
      meta_get "feature-error" "$cache_dir"
      ;;
    "metadata")
      meta_get "metadata-error" "$cache_dir"
      ;;
    "build-data")
      meta_get "build-data-error" "$cache_dir"
      ;;
    "unknown")
      meta_get "unknown-error" "$cache_dir"
      ;;
    *)
      echo "Unknown error type: $error_type"
      ;;
  esac
}

# Log failure
log_failure() {
  local build_dir="$1"
  local cache_dir="$2"
  local error_type="$3"
  local error="$4"

  puts_error "Build failed: $error_type"
  puts_error "Error: $error"
  meta_set "failure-type" "$error_type" "$cache_dir"
  meta_set "failure-message" "$error" "$cache_dir"
  meta_set "build-status" "failed" "$cache_dir"
}

# Check for failures
check_failures() {
  local cache_dir="$1"
  local error_type="$2"

  if [ -n "$(meta_get "failure-type" "$cache_dir")" ]; then
    if [ -z "$error_type" ] || [ "$(meta_get "failure-type" "$cache_dir")" = "$error_type" ]; then
      return 0
    fi
  fi
  return 1
}

# Clear failures
clear_failures() {
  local cache_dir="$1"

  meta_remove "failure-type" "$cache_dir"
  meta_remove "failure-message" "$cache_dir"
  meta_remove "build-status" "$cache_dir"
}

# Get failure report
get_failure_report() {
  local cache_dir="$1"

  echo "Failure Report"
  echo "============="
  echo "Type: $(meta_get "failure-type" "$cache_dir")"
  echo "Message: $(meta_get "failure-message" "$cache_dir")"
  echo "Status: $(meta_get "build-status" "$cache_dir")"
}

fail() {
  meta_time "build-time" "$build_start_time"
  log_meta_data >> "$BUILDPACK_LOG_FILE"
  exit 1
}

failure_message() {
  local warn

  warn="$(cat "$warnings")"

  echo ""
  echo "We're sorry this build is failing!"
  echo ""
  if [ "$warn" != "" ]; then
    echo "Some possible problems:"
    echo ""
    echo "$warn"
  else
    echo "If you're stuck, please send us an email so we can help:"
    echo "rddwarf03@gmail.com"
  fi
  echo ""
  echo "Keep coding,"
  echo "RedDwarf"
  echo ""
}

fail_invalid_pubspec_yaml() {
  local is_invalid

  is_invalid=$(is_invalid_yaml_file "${1:-}/pubspec.yaml")

  if "$is_invalid"; then
    error "Unable to parse pubspec.yaml"
    mcount 'failures.parse.pubspec-yaml'
    meta_set "failure" "invalid-pubspec-yaml"
    header "Build failed"
    failure_message
    fail
  fi
}

fail_dot_scalingo() {
  if [ -f "${1:-}/.scalingo" ]; then
    mcount "failures.dot-scalingo"
    meta_set "failure" "dot-scalingo"
    header "Build failed"
    warn "The directory .scalingo could not be created

       It looks like a .scalingo file is checked into this project.
       The Dart buildpack uses the hidden directory .scalingo to store
       binaries like the Dart SDK and pub. You should remove the
       .scalingo file or ignore it by adding it to .slugignore
       "
    fail
  fi
}

fail_dot_scalingo_dart() {
  if [ -f "${1:-}/.scalingo/dart" ]; then
    mcount "failures.dot-scalingo-dart"
    meta_set "failure" "dot-scalingo-dart"
    header "Build failed"
    warn "The directory .scalingo/dart could not be created

       It looks like a .scalingo file is checked into this project.
       The Dart buildpack uses the hidden directory .scalingo to store
       binaries like the Dart SDK and pub. You should remove the
       .scalingo file or ignore it by adding it to .slugignore
       "
    fail
  fi
}

fail_dart_install() {
  local dart_engine
  local log_file="$1"
  local build_dir="$2"

  if grep -qi 'Could not find Dart version corresponding to version requirement' "$log_file"; then
    dart_engine=$(read_yaml "$build_dir/pubspec.yaml" ".environment.sdk")
    mcount "failures.invalid-dart-version"
    meta_set "failure" "invalid-dart-version"
    echo ""
    warn "No matching version found for Dart: $dart_engine

       Scalingo supports the latest Stable version of Dart as well as all
       active versions, however you have specified a version in pubspec.yaml
       ($dart_engine) that does not correspond to any published version of Dart.

       You should always specify a Dart version that matches the runtime
       you're developing and testing with. To find your version locally:

       $ dart --version

       Use the environment section of your pubspec.yaml to specify the version of
       Dart to use on Scalingo:

       environment:
         sdk: '>=3.0.0 <4.0.0'
    "
    fail
    exit 1
  fi
}

fail_pub_get() {
  local log_file="$1"
  if grep -qi 'pub get failed' "$log_file"; then
    mcount "failures.pub-get"
    meta_set "failure" "pub-get-failed"
    echo ""
    warn "Pub Get Failed

       Failed to get dependencies. This can happen for several reasons:
       1. Invalid dependency constraints in pubspec.yaml
       2. Package not found
       3. Version conflict between dependencies
       4. Network issues

       Check the error message above for more details.
       Try running 'dart pub get' locally to reproduce the error.
    "
    fail
    exit 1
  fi
}

fail_dart_compile() {
  local log_file="$1"
  if grep -qi 'compilation failed' "$log_file"; then
    mcount "failures.compilation"
    meta_set "failure" "compilation-failed"
    echo ""
    warn "Dart Compilation Failed

       The Dart compiler encountered errors. This can happen due to:
       1. Syntax errors
       2. Type errors
       3. Missing dependencies
       4. Invalid imports

       Check the error messages above for more details.
       Try running 'dart compile' locally to reproduce the error.
    "
    fail
    exit 1
  fi
}

fail_dart_test() {
  local log_file="$1"
  if grep -qi 'test failed' "$log_file"; then
    mcount "failures.tests"
    meta_set "failure" "tests-failed"
    echo ""
    warn "Dart Tests Failed

       One or more tests failed during the build process.
       Check the test output above for more details.
       Try running 'dart test' locally to reproduce the failures.
    "
    fail
    exit 1
  fi
}

fail_dart_analyze() {
  local log_file="$1"
  if grep -qi 'Analysis failed' "$log_file"; then
    mcount "failures.analysis"
    meta_set "failure" "analysis-failed"
    echo ""
    warn "Dart Analysis Failed

       Static analysis found issues in your code.
       These could be:
       1. Potential bugs
       2. Dead code
       3. Violation of best practices
       4. Type errors

       Check the analysis output above for more details.
       Try running 'dart analyze' locally to reproduce the issues.
    "
    fail
    exit 1
  fi
}

fail_build_runner() {
  local log_file="$1"
  if grep -qi 'build_runner failed' "$log_file"; then
    mcount "failures.build-runner"
    meta_set "failure" "build-runner-failed"
    echo ""
    warn "Build Runner Failed

       The build_runner encountered errors. This can happen due to:
       1. Invalid build configuration
       2. Missing build dependencies
       3. Build script errors
       4. Asset generation failures

       Check the error messages above for more details.
       Try running 'dart run build_runner build' locally to reproduce the error.
    "
    fail
    exit 1
  fi
}

fail_web_compiler() {
  local log_file="$1"
  if grep -qi 'web compiler failed' "$log_file"; then
    mcount "failures.web-compiler"
    meta_set "failure" "web-compiler-failed"
    echo ""
    warn "Web Compiler Failed

       The web compiler encountered errors. This can happen due to:
       1. Invalid web configuration
       2. Missing web dependencies
       3. JavaScript compilation errors
       4. Asset bundling failures

       Check the error messages above for more details.
       Try running 'dart compile js' locally to reproduce the error.
    "
    fail
    exit 1
  fi
}

fail_native_compiler() {
  local log_file="$1"
  if grep -qi 'native compiler failed' "$log_file"; then
    mcount "failures.native-compiler"
    meta_set "failure" "native-compiler-failed"
    echo ""
    warn "Native Compiler Failed

       The native compiler encountered errors. This can happen due to:
       1. Invalid native configuration
       2. Missing native dependencies
       3. Platform-specific compilation errors
       4. Binary generation failures

       Check the error messages above for more details.
       Try running 'dart compile exe' locally to reproduce the error.
    "
    fail
    exit 1
  fi
}

fail_dependency_conflict() {
  local log_file="$1"
  if grep -qi 'dependency conflict' "$log_file"; then
    mcount "failures.dependency-conflict"
    meta_set "failure" "dependency-conflict"
    echo ""
    warn "Dependency Conflict Detected

       There is a conflict between package versions in your dependencies.
       This can happen when:
       1. Two packages require different versions of the same dependency
       2. A package requires a version that is incompatible with your SDK
       3. The dependency graph contains circular dependencies

       Check the error messages above for more details.
       Try running 'dart pub deps' locally to analyze your dependencies.
    "
    fail
    exit 1
  fi
}

fail_missing_assets() {
  local log_file="$1"
  if grep -qi 'missing assets' "$log_file"; then
    mcount "failures.missing-assets"
    meta_set "failure" "missing-assets"
    echo ""
    warn "Missing Assets

       Required assets are missing from your project.
       This can happen when:
       1. Asset files are not included in pubspec.yaml
       2. Asset paths are incorrect
       3. Asset files are not committed to version control

       Check the error messages above for more details.
       Verify your assets are properly listed in pubspec.yaml.
    "
    fail
    exit 1
  fi
}

fail_invalid_platform() {
  local log_file="$1"
  if grep -qi 'invalid platform' "$log_file"; then
    mcount "failures.invalid-platform"
    meta_set "failure" "invalid-platform"
    echo ""
    warn "Invalid Platform Configuration

       The platform configuration in your pubspec.yaml is invalid.
       This can happen when:
       1. Platform constraints are incorrectly specified
       2. Required platform-specific dependencies are missing
       3. Platform version requirements are incompatible

       Check the error messages above for more details.
       Verify your platform configuration in pubspec.yaml.
    "
    fail
    exit 1
  fi
}

fail_missing_executable() {
  local log_file="$1"
  if grep -qi 'missing executable' "$log_file"; then
    mcount "failures.missing-executable"
    meta_set "failure" "missing-executable"
    echo ""
    warn "Missing Executable

       The specified executable file is missing.
       This can happen when:
       1. The main entry point is not specified correctly
       2. The executable file is not included in the build
       3. The file path is incorrect

       Check the error messages above for more details.
       Verify your executable configuration in pubspec.yaml.
    "
    fail
    exit 1
  fi
}

log_other_failures() {
  local log_file="$1"

  if grep -qP "version \`GLIBC_\d+\.\d+' not found" "$log_file"; then
    mcount "failures.libc6-incompatibility"
    meta_set "failure" "libc6-incompatibility"
    warn "This Dart version is not compatible with the current stack.

       For Dart versions 3.0 and greater, scalingo-20 or newer is required.
       Consider updating to a stack that is compatible with the Dart version
       or pinning the Dart version to be compatible with the current
       stack."

    return 0
  fi
}
