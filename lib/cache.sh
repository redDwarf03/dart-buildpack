#!/usr/bin/env bash

# Dart specific cache handling script
create_signature() {
  local pubspec_hash=""
  if [ -f "$BUILD_DIR/pubspec.lock" ]; then
    pubspec_hash=$(sha256sum "$BUILD_DIR/pubspec.lock" | awk '{print $1}')
  fi
  
  echo "v3;${STACK};$(dart --version | awk 'NR==1{print $4}');${pubspec_hash};$(env | grep -E 'DART_|PUB_' | sort | sha256sum | cut -d' ' -f1)"
}

save_signature() {
  local cache_dir="$1"
  create_signature > "$cache_dir/dart/signature"
}

load_signature() {
  local cache_dir="$1"
  if test -f "$cache_dir/dart/signature"; then
    cat "$cache_dir/dart/signature"
  else
    echo ""
  fi
}

get_cache_status() {
  local cache_dir="$1"
  if ! ${DART_CACHE:-true}; then
    echo "disabled"
  elif ! test -d "$cache_dir/dart/"; then
    echo "not-found"
  elif [ "$(create_signature)" != "$(load_signature "$cache_dir")" ]; then
    echo "new-signature"
  else
    echo "valid"
  fi
}

restore_cache() {
  local build_dir="$1" cache_dir="$2"
  
  if [[ -d "$cache_dir/dart/cache" ]]; then
    echo "- Restoring Dart cache (rsync)"
    mkdir -p "$build_dir/.pub-cache"
    rsync -a "$cache_dir/dart/cache/" "$build_dir/.pub-cache/" || {
      warning "Cache restoration partial failure - continuing"
    }
  fi
}

clear_cache() {
  local cache_dir="$1"
  local backup_dir="$cache_dir/backup_$(date +%s)"
  
  mkdir -p "$backup_dir"
  mv "$cache_dir/dart" "$backup_dir" 2>/dev/null || true
  mkdir -p "$cache_dir/dart/cache"
  
  # Automatic clean after 24h
  find "$cache_dir" -name "backup_*" -mtime +1 -exec rm -rf {} \; &>/dev/null || true
}

save_cache() {
  local build_dir="$1" cache_dir="$2"
  
  if [[ -d "$build_dir/.pub-cache" ]]; then
    if ! diff -qr "$build_dir/.pub-cache" "$cache_dir/dart/cache" &>/dev/null; then
      echo "- Saving Dart cache (changed detected)"
      rm -rf "$cache_dir/dart/cache"
      cp -a "$build_dir/.pub-cache" "$cache_dir/dart/cache"
    else
      echo "- Dart cache (no changes - skipping)"
    fi
  fi
}

purge_large_cache() {
  local cache_dir="$1" max_size_mb=500
  
  if [ -d "$cache_dir/dart" ]; then
    local size_mb=$(du -sm "$cache_dir/dart" | cut -f1)
    if [ "$size_mb" -gt "$max_size_mb" ]; then
      warning "Purging oversized cache (${size_mb}MB > ${max_size_mb}MB)"
      rm -rf "$cache_dir/dart"
    fi
  fi
}

log_cache_stats() {
  local cache_dir="$1"
  echo "=== Cache Diagnostics ==="
  echo "Signature: $(load_signature "$cache_dir")"
  echo "Cache Size: $(du -sh "$cache_dir/dart" 2>/dev/null || echo 'N/A')"
  echo "Contents:"
  tree -L 2 "$cache_dir/dart" 2>/dev/null || ls -la "$cache_dir/dart"
}