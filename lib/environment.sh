#!/usr/bin/env bash

# System Detection
get_os() {
  uname | tr '[:upper:]' '[:lower:]'
}

get_cpu() {
  case "$(uname -m)" in
    i386|i686)   echo "x86" ;;
    x86_64)      echo "x64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)           echo "x64" ;;
  esac
}

get_platform() {
  echo "$(get_os)-$(get_cpu)"
}

# Dart Environment Configuration
create_default_env() {
  export DART_ENV=${DART_ENV:-production}
  export DART_VM_OPTIONS=${DART_VM_OPTIONS:-"--enable-asserts"}
  export PUB_CACHE=${PUB_CACHE:-"$HOME/.pub-cache"}
  
  # Flutter-specific configuration
  if command -v flutter &> /dev/null; then
    export FLUTTER_ROOT=${FLUTTER_ROOT:-$(dirname $(which flutter))}
    export FLUTTER_ENV=${FLUTTER_ENV:-production}
  fi
}

create_build_env() {
  create_default_env
  
  # Memory optimization for Dart VM
  if [[ -z $DART_VM_OPTIONS ]]; then
    export DART_VM_OPTIONS="--max-old-space-size=2560"
  fi
  
  # Build-specific configuration
  export PUB_ENVIRONMENT="scalingo_build"
}

# Configuration Display
list_dart_config() {
  echo ""
  echo "Dart Environment Configuration:"
  printenv | grep -E '^(DART_|PUB_|FLUTTER_)' || true
  
  if command -v dart &> /dev/null; then
    echo ""
    dart --version
  fi
  
  if command -v flutter &> /dev/null; then
    echo ""
    flutter --version
  fi
}

# Environment Variable Management
export_env_dir() {
  local env_dir=$1
  if [ -d "$env_dir" ]; then
    local whitelist_regex=${2:-''}
    local blacklist_regex=${3:-'^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH|LANG|BUILD_DIR)$'}
    pushd "$env_dir" >/dev/null
    for e in *; do
      [ -e "$e" ] || continue
      echo "$e" | grep -E "$whitelist_regex" | grep -qvE "$blacklist_regex" &&
      export "$e=$(cat "$e")"
    done
    popd >/dev/null
  fi
}

# Profile Management
write_profile() {
  local bp_dir="$1"
  local build_dir="$2"
  mkdir -p "$build_dir/.profile.d"
  [ -d "$bp_dir/profile" ] && cp "$bp_dir"/profile/* "$build_dir/.profile.d/" 2>/dev/null || true
}

write_ci_profile() {
  local bp_dir="$1"
  local build_dir="$2"
  write_profile "$1" "$2"
  [ -d "$bp_dir/ci-profile" ] && cp "$bp_dir"/ci-profile/* "$build_dir/.profile.d/" 2>/dev/null || true
}

# Export Configuration
write_export() {
  local bp_dir="$1"
  local build_dir="$2"

  if [ -w "$bp_dir" ]; then
    {
      echo "export PATH=\"$build_dir/.scalingo/dart-sdk/bin:\$PATH\""
      echo "export DART_SDK=\"$build_dir/.scalingo/dart-sdk\""
      echo "export PUB_CACHE=\"\${PUB_CACHE:-$build_dir/.pub-cache}\""
      echo "export DART_VM_OPTIONS=\"\${DART_VM_OPTIONS:---max-old-space-size=2560}\""
      
      if command -v flutter &> /dev/null; then
        echo "export FLUTTER_ROOT=\"$build_dir/.scalingo/flutter\""
        echo "export PATH=\"\$FLUTTER_ROOT/bin:\$PATH\""
      fi
    } > "$bp_dir/export"
  fi
}

# Dart-specific additional function
generate_dart_defines() {
  local build_dir="$1"
  if [ -f "$build_dir/dart-defines.yaml" ]; then
    yq eval -o=j "$build_dir/dart-defines.yaml" | jq -r 'to_entries|map("--dart-define=\(.key)=\(.value|@uri)")|join(" ")' > "$build_dir/.dart-defines"
  fi
}