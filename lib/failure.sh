#!/usr/bin/env bash

# Enhanced Dart Buildpack Failure Handling
# Features:
# - Structured error logging
# - Advanced Dart error detection
# - Automated error reporting
# - Self-healing for known issues

### Initial Setup ###
set -o errexit
set -o pipefail
set -o nounset

# Safe initialization of critical variables
BUILDPACK_LOG_FILE=${BUILDPACK_LOG_FILE:-/dev/null}
LOG_FILE=${LOG_FILE:-/dev/null}
SENTRY_DSN=${SENTRY_DSN:-}
CRITICAL=${CRITICAL:-4} 
HIGH=${HIGH:-3} 
MEDIUM=${MEDIUM:-2} 
LOW=${LOW:-1} 
build_start_time=${build_start_time:-$(date +%s)}


# Temporary file management
warnings=$(mktemp -t "buildpack-warnings-XXXXXX") || {
    echo "ERROR: Failed to create temp file for warnings" >&2
    exit 1
}
trap 'rm -f "$warnings"' EXIT

### Core Functions ###

warning() {
    local tip=${1:-} url=${2:-} level=${3:-"MEDIUM"}
    local level_code=${WARNING_LEVELS[$level]:-2}  # Default to MEDIUM if invalid level
    
    {
    echo "[$level_code] ${tip}"
    echo "  ${url}"
    echo ""
    } >> "${warnings}"
}

# Structured logging
log_failure() {
    local type=${1:-unknown} message=${2:-}
    jq -n \
        --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg type "$type" \
        --arg message "$message" \
        '{timestamp: $time, severity: "ERROR", type: $type, message: $message}' \
        >> "${BUILDPACK_LOG_FILE}"
}

# Error reporting
report_to_sentry() {
    local error_type=${1:-} message=${2:-}
    if [ -n "${SENTRY_DSN:-}" ]; then
        curl -s -X POST "${SENTRY_DSN}" \
            -H "Content-Type: application/json" \
            -d @<(
                jq -n \
                    --arg message "$message" \
                    --arg type "$error_type" \
                    '{message: $message, level: "error", tags: {type: $type}}'
            ) || true
    fi
}

# Visual error display
show_error_banner() {
    local message=${1:-} tip=${2:-} url=${3:-}
    cat <<EOF | output "${LOG_FILE}"
╔══════════════════════════════════════════════════╗
║                  BUILD FAILED                    ║
╠══════════════════════════════════════════════════╣
║ ${message}
║ 
║ Tip: ${tip}
║ Link: ${url}
╚══════════════════════════════════════════════════╝
EOF
}

### Error Detection Functions ###

analyze_dart_stacktrace() {
    local log_file=${1:-}
    local pattern="'package:[^']+'"
    
    if grep -qE "$pattern" "${log_file}"; then
        mcount "failures.dart-package-error"
        meta_set "failure" "dart-package-error"
        
        local package=$(grep -oE "$pattern" "${log_file}" | head -1)
        warn "Package error detected in ${package}" \
             "https://dart.dev/tools/pub/dependencies"
        return 0
    fi
    return 1
}

detect_dependency_conflicts() {
    local log_file=${1:-}
    if grep -q "because .* depends on" "${log_file}"; then
        mcount "failures.dependency-conflict"
        meta_set "failure" "dependency-conflict"
        
        local conflict=$(grep -m1 -o "because .* depends on .*" "${log_file}")
        warn "Dependency conflict detected: ${conflict}" \
             "https://dart.dev/tools/pub/dependencies#dependency-resolution"
        return 0
    fi
    return 1
}

### Enhanced Failure Handlers ###

fail_invalid_pubspec() {

    local pubspec="pubspec.yaml"
    local yaml_errors=$(yamllint "${pubspec}" 2>&1)
    
    if [ $? -ne 0 ]; then
        meta_set "failure" "invalid-pubspec-yaml"
        mcount "failures.parse.pubspec-yaml"
        
        show_error_banner \
            "Invalid pubspec.yaml detected" \
            "Check your YAML syntax using online validators" \
            "https://yamlvalidator.com"
        
        log_failure "yaml-syntax" "${yaml_errors}"
        report_to_sentry "invalid-pubspec" "${yaml_errors}"
        fail
    fi

    # Validate required fields
    local required_fields=("name" "version" "environment")
    for field in "${required_fields[@]}"; do
        if ! grep -q "^${field}:" "${pubspec}"; then
            warning "Missing required field in pubspec.yaml: ${field}" \
                   "https://dart.dev/tools/pub/pubspec" \
                   "HIGH"
            meta_set "failure" "missing-${field}"
            mcount "failures.missing-${field}"
        fi
    done    
}

fail_dot_dart_tool() {
    if [ -f "${1:-}/.dart_tool" ]; then
        mcount "failures.dot-dart-tool"
        meta_set "failure" "dot-dart-tool"
        
        show_error_banner \
            "Invalid .dart_tool file detected" \
            "Remove this file as it conflicts with Dart's build system" \
            "https://dart.dev/tools/dart-tool"
        
        log_failure "dot-dart-tool" ".dart_tool file present"
        fail
    fi
}

### Dependency Failure Handling ###

fail_outdated_package_manager() {
    local log_file="${1:-}"
    if grep -qi 'error .install. has been replaced with .add.' "${log_file}"; then
        local version=$(dart --version 2>&1 || echo "unknown")
        
        mcount "failures.outdated-flutter"
        meta_set "failure" "outdated-flutter"
        
        show_error_banner \
            "Outdated Dart/Flutter version (${version})" \
            "Update your Dart/Flutter SDK to the latest stable version" \
            "https://dart.dev/get-dart"
        
        log_failure "outdated-sdk" "Version: ${version}"
        fail
    fi
}

### Warning System ###

warning() {
    local tip=${1:-} url=${2:-} level=${3:-"MEDIUM"}
    {
    echo "[${WARNING_LEVELS[${level}]:-2}] ${tip}"
    echo "  ${url}"
    echo ""
    } >> "${warnings}"
}

warn() {
    local tip=${1:-} url=${2:-}
    echo " !     ${tip}" >&2
    echo "       ${url}" >&2
    echo "" >&2
}

### Self-Healing Functions ###

try_autofix() {
    case $(meta_get "failure") in
        "dart-sdk-incompatibility")
            warn "Attempting to fix by updating Dart SDK..."
            install_dart_sdk
            return $?
            ;;
        "dependency-resolution-failure")
            warn "Attempting dependency override..."
            dart pub override --no-allow-prereleases
            return $?
            ;;
        *)
            return 1
            ;;
    esac
}

### Core Failure Handler ###

fail() {
    local exit_code=${?}
    
    # Log final metrics
    meta_time "build-time" "${build_start_time}"
    log_meta_data >> "${BUILDPACK_LOG_FILE}"
    
    # Attempt self-healing
    if try_autofix; then
        warning "Automatic recovery attempted" \
               "https://dart.dev/tools/pub/troubleshoot" \
               "MEDIUM"
        return  # Continue build
    fi
    
    # Show failure message
    failure_message | output "${LOG_FILE}"
    
    # Report to error tracking
    report_to_sentry "$(meta_get "failure")" "Build failed with code ${exit_code}"
    
    exit ${exit_code}
}

### Public API ###

failure_message() {
    local warn_content=$(cat "${warnings}")
    
    echo ""
    echo "We're sorry this build is failing! Here's what we found:"
    echo ""
    
    if [ -n "${warn_content}" ]; then
        echo "Detected issues:"
        echo "${warn_content}" | sort -nr | cut -d']' -f2-
    else
        echo "No specific issues detected. Please check your build configuration."
    fi
    
    echo ""
    echo "For more help, see: https://dart.dev/tools/pub/troubleshoot"
    echo ""
}

log_other_failures() {
    local log_file="${1:-}"
    
    analyze_dart_stacktrace "${log_file}" ||
    detect_dependency_conflicts "${log_file}" ||
    fail_outdated_package_manager "${log_file}"
}

warn_missing_pubspec() {
  

  if [[ ! -f "pubspec.yaml" ]]; then
    warning "Missing pubspec.yaml" \
           "https://dart.dev/tools/pub/pubspec" \
           "CRITICAL"
    mcount 'failures.missing-pubspec'
  fi
}



fail_dot_scalingo() {
  if [ -f "${1:-}/.scalingo" ]; then
    mcount "failures.dot-scalingo"
    meta_set "failure" "dot-scalingo"
    header "Build failed"
    warn "The directory .scalingo could not be created

       It looks like a .scalingo file is checked into this project.
       The Node.js buildpack uses the hidden directory .scalingo to store
       binaries like the node runtime and npm. You should remove the
       .scalingo file or ignore it by adding it to .slugignore
       "
    fail
  fi
}


fail_dot_scalingo_node() {
  if [ -f "${1:-}/.scalingo/node" ]; then
    mcount "failures.dot-scalingo-node"
    meta_set "failure" "dot-scalingo-node"
    header "Build failed"
    warn "The directory .scalingo/node could not be created

       It looks like a .scalingo file is checked into this project.
       The Node.js buildpack uses the hidden directory .scalingo to store
       binaries like the node runtime and npm. You should remove the
       .scalingo file or ignore it by adding it to .slugignore
       "
    fail
  fi
}

# Export public functions
export -f failure_message log_other_failures warn warning