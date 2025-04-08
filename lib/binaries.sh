#!/usr/bin/env bash

# shellcheck source=lib/vendor/stdlib_v7.sh
source "$BP_DIR/lib/vendor/stdlib_v7.sh"

RESOLVE="$BP_DIR/lib/vendor/resolve-version-$(get_os)"

# Fonction pour résoudre la version de Dart à installer
# @param $1 binary - Nom du binaire (dart)
# @param $2 versionRequirement - Version requise ou contrainte
# @return La version exacte à installer ou une erreur si non trouvée
resolve() {
  local binary="$1"
  local versionRequirement="$2"
  local inventory_file="$BP_DIR/inventory/$binary.toml"
  local yq_cmd

  echo "DEBUG: Resolving version requirement: $versionRequirement"
  echo "DEBUG: Using inventory file: $inventory_file"

  # Déterminer la commande yq à utiliser
  case $(uname) in
    Darwin) yq_cmd="$BP_DIR/lib/vendor/yq-darwin";;
    Linux) yq_cmd="$BP_DIR/lib/vendor/yq-linux";;
    *) yq_cmd="yq";;
  esac

  # Lire toutes les versions disponibles
  local versions
  versions=$("$yq_cmd" read "$inventory_file" "releases[*].version")
  echo "DEBUG: Available versions: $versions"

  # Si la contrainte est une version exacte
  if [[ "$versionRequirement" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "DEBUG: Exact version requirement"
    # Vérifier si la version existe
    if echo "$versions" | grep -q "^$versionRequirement$"; then
      local url
      url=$("$yq_cmd" read "$inventory_file" "releases(version==$versionRequirement).url")
      echo "$versionRequirement $url"
      return 0
    fi
  # Si la contrainte est de la forme >=x.y.z <a.b.c
  elif [[ "$versionRequirement" =~ ^\>=([0-9]+\.[0-9]+\.[0-9]+)\s*\<([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    echo "DEBUG: Range version requirement"
    local min_version="${BASH_REMATCH[1]}"
    local max_version="${BASH_REMATCH[2]}"
    echo "DEBUG: Min version: $min_version"
    echo "DEBUG: Max version: $max_version"
    
    # Trouver la version la plus récente qui satisfait la contrainte
    local latest_version=""
    while read -r version; do
      echo "DEBUG: Checking version: $version"
      if [ "$(printf '%s\n' "$version" "$min_version" | sort -V | head -n1)" = "$min_version" ] && \
         [ "$(printf '%s\n' "$version" "$max_version" | sort -V | head -n1)" = "$version" ]; then
        echo "DEBUG: Version $version satisfies constraint"
        if [ -z "$latest_version" ] || [ "$(printf '%s\n' "$version" "$latest_version" | sort -V | tail -n1)" = "$version" ]; then
          latest_version="$version"
          echo "DEBUG: New latest version: $latest_version"
        fi
      fi
    done <<< "$versions"

    if [ -n "$latest_version" ]; then
      local url
      url=$("$yq_cmd" read "$inventory_file" "releases(version==$latest_version).url")
      echo "$latest_version $url"
      return 0
    fi
  fi

  echo "No result"
  return 1
}

# Fonction pour installer le SDK Dart
# @param $1 dir - Répertoire d'installation
# @param $2 version - Version de Dart à installer (par défaut: stable)
# @return 0 si l'installation réussit, 1 sinon
install_dart_sdk() {
  local dir="$1"
  local version="${2:-stable}"
  local platform="$(get_platform)"
  local url code

  if [[ -n "$DART_SDK_URL" ]]; then
    url="$DART_SDK_URL"
    echo "Downloading and installing Dart SDK from $url"
  else
    echo "Resolving Dart SDK version $version..."
    local resolve_result
    resolve_result=$(resolve dart "$version" || echo "failed")

    if [[ "$resolve_result" == "failed" ]]; then
      fail_bin_install dart "$version"
    fi

    read -r number url < <(echo "$resolve_result")
    echo "Downloading and installing Dart SDK $number..."
  fi

  code=$(curl "$url" -L --silent --fail --retry 5 --retry-max-time 15 --retry-connrefused --connect-timeout 5 -o /tmp/dart-sdk.zip --write-out "%{http_code}")

  if [ "$code" != "200" ]; then
    echo "Unable to download Dart SDK: $code" && false
  fi

  rm -rf "${dir:?}"/*
  unzip -q /tmp/dart-sdk.zip -d "$dir"
  mv "$dir/dart-sdk"/* "$dir"
  rmdir "$dir/dart-sdk"
  chmod +x "$dir"/bin/*

  # Verify dart works
  suppress_output dart --version
  echo "Installed Dart SDK $(dart --version)"
}

# Fonction pour installer les outils Dart de base
# @param $1 dir - Répertoire d'installation
# @param $2 tools - Liste des outils à installer
# @return 0 si l'installation réussit, 1 sinon
install_dart_tools() {
  local dir="$1"
  local tools=("$@")

  echo "Installing Dart tools..."
  
  # Ensure pub is available
  if ! command -v pub >/dev/null; then
    echo "Error: pub command not found. Is the Dart SDK properly installed?" && false
  fi

  for tool in "${tools[@]}"; do
    echo "Installing $tool..."
    if ! pub global activate "$tool" >/dev/null; then
      echo "Failed to install $tool" && false
    fi
  done

  echo "Dart tools installation complete"
}

# Fonction pour installer les outils de développement Dart
# @param $1 dir - Répertoire d'installation
# @return 0 si l'installation réussit, 1 sinon
install_dart_dev_tools() {
  local dir="$1"
  
  echo "Installing Dart development tools..."

  # Install common development tools
  local dev_tools=(
    "devtools"      # Dart DevTools
    "dart_style"    # Dart formatter
    "analyzer"      # Dart analyzer
    "coverage"      # Code coverage tool
    "dartdoc"       # Documentation generator
  )

  install_dart_tools "$dir" "${dev_tools[@]}"
}

# Fonction pour installer les outils de construction Dart
# @param $1 dir - Répertoire d'installation
# @return 0 si l'installation réussit, 1 sinon
install_dart_build_tools() {
  local dir="$1"
  
  echo "Installing Dart build tools..."

  # Install build tools
  local build_tools=(
    "build_runner"  # Build system
    "build_web_compilers"  # Web compilation
    "build_daemon"  # Build daemon
  )

  install_dart_tools "$dir" "${build_tools[@]}"
}

# Fonction pour installer les outils de test Dart
# @param $1 dir - Répertoire d'installation
# @return 0 si l'installation réussit, 1 sinon
install_dart_test_tools() {
  local dir="$1"
  
  echo "Installing Dart test tools..."

  # Install test tools
  local test_tools=(
    "test"         # Test runner
    "test_coverage"  # Test coverage
    "mockito"      # Mocking framework
  )

  install_dart_tools "$dir" "${test_tools[@]}"
}

# Fonction pour gérer les erreurs d'installation des binaires
# @param $1 binary - Nom du binaire
# @param $2 version - Version demandée
# @param $3 error_type - Type d'erreur (optionnel)
# @return 1 (toujours)
fail_bin_install() {
  local binary="$1"
  local version="$2"
  local error_type="${3:-}"
  if [[ -z "$error_type" ]]; then
    error_type="version-not-found"
  fi
  meta_set "failure" "$error_type"
  case "$error_type" in
    "version-not-found")
      error "Could not find Dart version corresponding to version requirement: $version

       Scalingo supports the latest stable version of Dart as well as recent
       releases. You can specify a Dart version in your pubspec.yaml:

       environment:
         sdk: '>=3.0.0 <4.0.0'

       See https://dart.dev/get-dart for all available versions."
      ;;
    "download-failed")
      error "Failed to download $binary

       This is usually due to network issues. Please try again later."
      ;;
    "invalid-checksum")
      error "Downloaded $binary archive has invalid checksum

       This could be due to network issues or tampering. Please try again."
      ;;
    *)
      error "Unknown error occurred while installing $binary

       Please try again or contact support if the issue persists."
      ;;
  esac
  return 1
}

# Fonction pour supprimer la sortie d'une commande
# @param $@ command - Commande à exécuter
# @return Le code de retour de la commande
suppress_output() {
  local TMP_COMMAND_OUTPUT
  TMP_COMMAND_OUTPUT=$(mktemp)
  trap "rm -rf '$TMP_COMMAND_OUTPUT' >/dev/null" RETURN

  "$@" >"$TMP_COMMAND_OUTPUT" 2>&1 || {
    local exit_code="$?"
    cat "$TMP_COMMAND_OUTPUT"
    return "$exit_code"
  }
  return 0
}

# Fonction pour installer Dart
# @param $1 dir - Répertoire d'installation
# @param $2 version - Version de Dart à installer (par défaut: stable)
# @return 0 si l'installation réussit, 1 sinon
install_dart() {
  local dir="$1"
  local version="${2:-stable}"
  
  echo "Installing Dart version $version..."
  
  if ! install_dart_sdk "$dir" "$version"; then
    echo "Failed to install Dart SDK"
    return 1
  fi
  
  echo "Dart installation complete"
  return 0
}
