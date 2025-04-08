#!/usr/bin/env bash

# shellcheck source=lib/vendor/stdlib_v7.sh
source "$BP_DIR/lib/vendor/stdlib_v7.sh"

get_os() {
  uname | tr '[:upper:]' '[:lower:]'
}

get_cpu() {
  if [[ "$(uname -p)" = "i686" ]]; then
    echo "x86"
  else
    echo "x64"
  fi
}

get_platform() {
  os=$(get_os)
  cpu=$(get_cpu)
  echo "$os-$cpu"
}

# Fonction pour créer les variables d'environnement par défaut pour Dart
# @param $1 build_dir - Répertoire de build
# @return 0 si la création réussit, 1 sinon
create_default_env() {
  local build_dir="$1"

  # Variables d'environnement Dart
  export DART_SDK="${DART_SDK:-$build_dir/dart-sdk}"
  export PUB_CACHE="${PUB_CACHE:-$build_dir/.pub-cache}"
  export DART_ENV="${DART_ENV:-production}"
  export DART_BUILD_FLAGS="${DART_BUILD_FLAGS:-}"
  export DART_VERBOSE="${DART_VERBOSE:-false}"
  export DART_PACKAGES_CACHE="${DART_PACKAGES_CACHE:-true}"

  # Chemins
  export PATH="$DART_SDK/bin:$PUB_CACHE/bin:$PATH"

  return 0
}

# Fonction pour configurer l'environnement de build
# @param $1 build_dir - Répertoire de build
# @return 0 si la configuration réussit, 1 sinon
setup_build_env() {
  local build_dir="$1"

  # Crée les variables d'environnement par défaut
  create_default_env "$build_dir"

  # Configure les flags de build
  if [ "$DART_VERBOSE" = "true" ]; then
    export DART_BUILD_FLAGS="$DART_BUILD_FLAGS --verbose"
  fi

  # Configure le cache des packages
  if [ "$DART_PACKAGES_CACHE" = "true" ]; then
    mkdir -p "$PUB_CACHE"
  fi

  return 0
}

# Fonction pour lister la configuration Dart
# @return La configuration Dart au format JSON
list_dart_config() {
  local config="{}"

  # Ajoute les variables d'environnement
  config=$(jq -n \
    --arg sdk "$DART_SDK" \
    --arg cache "$PUB_CACHE" \
    --arg env "$DART_ENV" \
    --arg flags "$DART_BUILD_FLAGS" \
    --arg verbose "$DART_VERBOSE" \
    --arg packages_cache "$DART_PACKAGES_CACHE" \
    '{
      "DART_SDK": $sdk,
      "PUB_CACHE": $cache,
      "DART_ENV": $env,
      "DART_BUILD_FLAGS": $flags,
      "DART_VERBOSE": $verbose,
      "DART_PACKAGES_CACHE": $packages_cache
    }')

  echo "$config"
}

# Fonction pour exporter les répertoires d'environnement
# @param $1 build_dir - Répertoire de build
# @return 0 si l'export réussit, 1 sinon
export_env_dirs() {
  local build_dir="$1"

  # Exporte les répertoires
  export_env_dir "$DART_SDK"
  export_env_dir "$PUB_CACHE"
  export_env_dir "$build_dir/.dart_tool"

  return 0
}

# Fonction pour écrire le script de profil
# @param $1 build_dir - Répertoire de build
# @return 0 si l'écriture réussit, 1 sinon
write_profile() {
  local build_dir="$1"

  mkdir -p "$build_dir/.profile.d"
  cat <<EOF >"$build_dir/.profile.d/dart.sh"
export DART_SDK="$DART_SDK"
export PUB_CACHE="$PUB_CACHE"
export DART_ENV="$DART_ENV"
export DART_BUILD_FLAGS="$DART_BUILD_FLAGS"
export DART_VERBOSE="$DART_VERBOSE"
export DART_PACKAGES_CACHE="$DART_PACKAGES_CACHE"
export PATH="\$DART_SDK/bin:\$PUB_CACHE/bin:\$PATH"
EOF

  return 0
}

# Fonction pour écrire le script d'export
# @param $1 build_dir - Répertoire de build
# @return 0 si l'écriture réussit, 1 sinon
write_export() {
  local build_dir="$1"

  mkdir -p "$build_dir/.export.d"
  cat <<EOF >"$build_dir/.export.d/dart.sh"
export DART_SDK="$DART_SDK"
export PUB_CACHE="$PUB_CACHE"
export DART_ENV="$DART_ENV"
export DART_BUILD_FLAGS="$DART_BUILD_FLAGS"
export DART_VERBOSE="$DART_VERBOSE"
export DART_PACKAGES_CACHE="$DART_PACKAGES_CACHE"
export PATH="\$DART_SDK/bin:\$PUB_CACHE/bin:\$PATH"
EOF

  return 0
}

# Fonction pour vérifier l'environnement
# @param $1 build_dir - Répertoire de build
# @return 0 si la vérification réussit, 1 sinon
check_env() {
  local build_dir="$1"

  # Vérifie les variables d'environnement
  if [ -z "$DART_SDK" ]; then
    echo "Error: DART_SDK is not set" && false
  fi

  if [ -z "$PUB_CACHE" ]; then
    echo "Error: PUB_CACHE is not set" && false
  fi

  if [ -z "$DART_ENV" ]; then
    echo "Error: DART_ENV is not set" && false
  fi

  # Vérifie les répertoires
  if [ ! -d "$DART_SDK" ]; then
    echo "Error: DART_SDK directory does not exist" && false
  fi

  if [ ! -d "$PUB_CACHE" ]; then
    echo "Error: PUB_CACHE directory does not exist" && false
  fi

  return 0
}

# Fonction pour valider l'environnement
# @param $1 build_dir - Répertoire de build
# @return 0 si la validation réussit, 1 sinon
validate_env() {
  local build_dir="$1"

  # Vérifie l'environnement
  if ! check_env "$build_dir"; then
    return 1
  fi

  # Vérifie les binaires
  if ! command -v dart >/dev/null; then
    echo "Error: dart command not found" && false
  fi

  if ! command -v pub >/dev/null; then
    echo "Error: pub command not found" && false
  fi

  # Vérifie la version de Dart
  if ! dart --version >/dev/null; then
    echo "Error: dart --version failed" && false
  fi

  # Vérifie le cache des packages
  if [ "$DART_PACKAGES_CACHE" = "true" ]; then
    if [ ! -d "$PUB_CACHE" ]; then
      echo "Error: PUB_CACHE directory does not exist" && false
    fi
  fi

  return 0
}
