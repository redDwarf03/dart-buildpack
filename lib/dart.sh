#!/usr/bin/env bash

# shellcheck source=lib/vendor/stdlib_v7.sh
source "$BP_DIR/lib/vendor/stdlib_v7.sh"

# Fonction pour obtenir la version de Dart
# @return La version de Dart ou une chaîne vide si non trouvée
get_dart_version() {
  if command -v dart >/dev/null; then
    dart --version | head -n1 | cut -d' ' -f2
  else
    echo ""
  fi
}

# Fonction pour obtenir la version du SDK Dart
# @return La version du SDK Dart ou une chaîne vide si non trouvée
get_dart_sdk_version() {
  if command -v dart >/dev/null; then
    dart --version | head -n1 | cut -d' ' -f2
  else
    echo ""
  fi
}

# Fonction pour obtenir la version de pub
# @return La version de pub ou une chaîne vide si non trouvée
get_pub_version() {
  if command -v pub >/dev/null; then
    pub --version | head -n1 | cut -d' ' -f2
  else
    echo ""
  fi
}

# Fonction pour obtenir la version de Flutter
# @return La version de Flutter ou une chaîne vide si non trouvée
get_flutter_version() {
  if command -v flutter >/dev/null; then
    flutter --version | head -n1 | cut -d' ' -f2
  else
    echo ""
  fi
}

# Fonction pour obtenir la version de Dart spécifiée dans pubspec.yaml
# @param $1 build_dir - Répertoire de build
# @return La version de Dart spécifiée ou une chaîne vide si non trouvée
get_dart_version_from_pubspec() {
  local build_dir="$1"

  if [ -f "$build_dir/pubspec.yaml" ]; then
    yq -r '.environment.sdk' "$build_dir/pubspec.yaml"
  else
    echo ""
  fi
}

# Fonction pour vérifier si une version de Dart est compatible
# @param $1 version - Version à vérifier
# @param $2 constraint - Contrainte de version
# @return 0 si la version est compatible, 1 sinon
check_dart_version_compatibility() {
  local version="$1"
  local constraint="$2"

  if [ -z "$version" ] || [ -z "$constraint" ]; then
    return 1
  fi

  # Vérifie si la version est compatible avec la contrainte
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    if [[ "$constraint" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      if [ "$version" = "$constraint" ]; then
        return 0
      fi
    elif [[ "$constraint" =~ ^[0-9]+\.[0-9]+\.[0-9]+\s*-\s*[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      local min_version
      local max_version
      min_version=$(echo "$constraint" | cut -d'-' -f1 | tr -d ' ')
      max_version=$(echo "$constraint" | cut -d'-' -f2 | tr -d ' ')
      if [ "$version" \> "$min_version" ] && [ "$version" \< "$max_version" ]; then
        return 0
      fi
    elif [[ "$constraint" =~ ^\>=.*\<.* ]]; then
      local min_version
      local max_version
      min_version=$(echo "$constraint" | sed -E 's/^>=\s*([0-9]+\.[0-9]+\.[0-9]+)\s*<.*$/\1/')
      max_version=$(echo "$constraint" | sed -E 's/^.*<\s*([0-9]+\.[0-9]+\.[0-9]+)$/\1/')
      if [ "$(printf '%s\n' "$version" "$min_version" | sort -V | head -n1)" = "$min_version" ] && \
         [ "$(printf '%s\n' "$version" "$max_version" | sort -V | head -n1)" = "$version" ]; then
        return 0
      fi
    fi
  fi

  return 1
}

# Fonction pour vérifier si Dart est installé
# @return 0 si Dart est installé, 1 sinon
check_dart_installed() {
  if command -v dart >/dev/null; then
    return 0
  else
    return 1
  fi
}

# Fonction pour vérifier si pub est installé
# @return 0 si pub est installé, 1 sinon
check_pub_installed() {
  if command -v pub >/dev/null; then
    return 0
  else
    return 1
  fi
}

# Fonction pour vérifier si Flutter est installé
# @return 0 si Flutter est installé, 1 sinon
check_flutter_installed() {
  if command -v flutter >/dev/null; then
    return 0
  else
    return 1
  fi
}

# Fonction pour vérifier si le projet est un projet Dart
# @param $1 build_dir - Répertoire de build
# @return 0 si c'est un projet Dart, 1 sinon
check_dart_project() {
  local build_dir="$1"

  if [ -f "$build_dir/pubspec.yaml" ]; then
    return 0
  else
    return 1
  fi
}

# Fonction pour vérifier si le projet est un projet Flutter
# @param $1 build_dir - Répertoire de build
# @return 0 si c'est un projet Flutter, 1 sinon
check_flutter_project() {
  local build_dir="$1"

  if [ -f "$build_dir/pubspec.yaml" ] && [ -f "$build_dir/lib/main.dart" ]; then
    if grep -q "flutter:" "$build_dir/pubspec.yaml"; then
      return 0
    fi
  fi

  return 1
}

# Fonction pour obtenir le type de projet Dart
# @param $1 build_dir - Répertoire de build
# @return Le type de projet (dart/flutter) ou une chaîne vide si non trouvé
get_project_type() {
  local build_dir="$1"

  if check_flutter_project "$build_dir"; then
    echo "flutter"
  elif check_dart_project "$build_dir"; then
    echo "dart"
  else
    echo ""
  fi
}

# Fonction pour obtenir les dépendances du projet
# @param $1 build_dir - Répertoire de build
# @return Les dépendances au format JSON ou un objet JSON vide si non trouvées
get_project_dependencies() {
  local build_dir="$1"
  local dependencies="{}"

  if [ -f "$build_dir/pubspec.yaml" ]; then
    dependencies=$(yq -r '.dependencies' "$build_dir/pubspec.yaml")
  fi

  echo "$dependencies"
}

# Fonction pour obtenir les dépendances de développement du projet
# @param $1 build_dir - Répertoire de build
# @return Les dépendances de développement au format JSON ou un objet JSON vide si non trouvées
get_project_dev_dependencies() {
  local build_dir="$1"
  local dev_dependencies="{}"

  if [ -f "$build_dir/pubspec.yaml" ]; then
    dev_dependencies=$(yq -r '.dev_dependencies' "$build_dir/pubspec.yaml")
  fi

  echo "$dev_dependencies"
}

# Fonction pour obtenir les scripts du projet
# @param $1 build_dir - Répertoire de build
# @return Les scripts au format JSON ou un objet JSON vide si non trouvés
get_project_scripts() {
  local build_dir="$1"
  local scripts="{}"

  if [ -f "$build_dir/pubspec.yaml" ]; then
    scripts=$(yq -r '.scripts' "$build_dir/pubspec.yaml")
  fi

  echo "$scripts"
}

# Fonction pour obtenir les configurations du projet
# @param $1 build_dir - Répertoire de build
# @return Les configurations au format JSON ou un objet JSON vide si non trouvées
get_project_config() {
  local build_dir="$1"
  local config="{}"

  if [ -f "$build_dir/pubspec.yaml" ]; then
    config=$(yq -r '.config' "$build_dir/pubspec.yaml")
  fi

  echo "$config"
}

# Fonction pour obtenir les métadonnées du projet
# @param $1 build_dir - Répertoire de build
# @return Les métadonnées au format JSON ou un objet JSON vide si non trouvées
get_project_metadata() {
  local build_dir="$1"
  local metadata="{}"

  if [ -f "$build_dir/pubspec.yaml" ]; then
    metadata=$(yq -r '.metadata' "$build_dir/pubspec.yaml")
  fi

  echo "$metadata"
}

# Fonction pour obtenir les informations du projet
# @param $1 build_dir - Répertoire de build
# @return Les informations du projet au format JSON
get_project_info() {
  local build_dir="$1"
  local info="{}"

  info=$(jq -n \
    --arg type "$(get_project_type "$build_dir")" \
    --arg version "$(get_dart_version_from_pubspec "$build_dir")" \
    --argjson dependencies "$(get_project_dependencies "$build_dir")" \
    --argjson dev_dependencies "$(get_project_dev_dependencies "$build_dir")" \
    --argjson scripts "$(get_project_scripts "$build_dir")" \
    --argjson config "$(get_project_config "$build_dir")" \
    --argjson metadata "$(get_project_metadata "$build_dir")" \
    '{
      "type": $type,
      "version": $version,
      "dependencies": $dependencies,
      "dev_dependencies": $dev_dependencies,
      "scripts": $scripts,
      "config": $config,
      "metadata": $metadata
    }')

  echo "$info"
}

# Fonction pour télécharger le SDK Dart
# @param $1 version - Version de Dart à télécharger
# @param $2 build_dir - Répertoire de build
# @return 0 si le téléchargement a réussi, 1 sinon
download_dart_sdk() {
  local version="$1"
  local build_dir="$2"
  local os
  local arch
  local url

  # Déterminer l'OS et l'architecture
  case "$(uname -s)" in
    Darwin) os="macos" ;;
    Linux) os="linux" ;;
    MINGW*|MSYS*|CYGWIN*) os="windows" ;;
    *) puts_error "Unsupported operating system"; return 1 ;;
  esac

  case "$(uname -m)" in
    x86_64) arch="x64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) puts_error "Unsupported architecture"; return 1 ;;
  esac

  # Construire l'URL de téléchargement
  url="https://storage.googleapis.com/dart-archive/channels/stable/release/$version/sdk/dartsdk-$os-$arch-release.zip"

  # Télécharger le SDK
  puts_info "Downloading Dart SDK version $version for $os-$arch..."
  if curl -L "$url" -o "$build_dir/dart-sdk.zip"; then
    puts_success "Dart SDK downloaded successfully"
    return 0
  else
    puts_error "Failed to download Dart SDK"
    return 1
  fi
}

# Fonction pour lister la configuration Dart
# @param $1 build_dir - Répertoire de build
# @return La configuration Dart
list_dart_config() {
  local build_dir="$1"
  local dart_bin="$build_dir/.scalingo/dart/bin/dart"
  
  if [ ! -x "$dart_bin" ]; then
    puts_error "Dart binary not found or not executable: $dart_bin"
    return 1
  fi
  
  echo "Dart SDK version: $("$dart_bin" --version)"
  echo "Dart pub version: $("$dart_bin" pub --version)"
}

read_yaml() {
  local file="$1"
  local path="$2"
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

  # Lire la valeur avec yq
  "$yq_cmd" read "$file" "$path"
}

# Run Dart command
run_dart() {
  local build_dir="$1"
  local command="$2"
  local args=("${@:3}")

  cd "$build_dir" || return 1

  if [ -f "pubspec.yaml" ]; then
    echo "Running: dart $command ${args[*]}"
    if dart "$command" "${args[@]}"; then
      mcount "dart.$command.success"
      return 0
    else
      mcount "dart.$command.failure"
      return 1
    fi
  else
    echo "No pubspec.yaml found"
    return 1
  fi
}

# Run pub command
run_pub() {
  local build_dir="$1"
  local command="$2"
  local args=("${@:3}")

  cd "$build_dir" || return 1

  if [ -f "pubspec.yaml" ]; then
    echo "Running: dart pub $command ${args[*]}"
    if dart pub "$command" "${args[@]}"; then
      mcount "pub.$command.success"
      return 0
    else
      mcount "pub.$command.failure"
      return 1
    fi
  else
    echo "No pubspec.yaml found"
    return 1
  fi
}

# Run build_runner command
run_build_runner() {
  local build_dir="$1"
  local command="$2"
  local args=("${@:3}")

  cd "$build_dir" || return 1

  if [ -f "pubspec.yaml" ]; then
    echo "Running: dart run build_runner $command ${args[*]}"
    if dart run build_runner "$command" "${args[@]}"; then
      mcount "build_runner.$command.success"
      return 0
    else
      mcount "build_runner.$command.failure"
      return 1
    fi
  else
    echo "No pubspec.yaml found"
    return 1
  fi
}

# Run analyzer command
run_analyzer() {
  local build_dir="$1"
  local args=("${@:2}")

  cd "$build_dir" || return 1

  if [ -f "pubspec.yaml" ]; then
    echo "Running: dart analyze ${args[*]}"
    if dart analyze "${args[@]}"; then
      mcount "analyzer.success"
      return 0
    else
      mcount "analyzer.failure"
      return 1
    fi
  else
    echo "No pubspec.yaml found"
    return 1
  fi
}

# Run test command
run_test() {
  local build_dir="$1"
  local args=("${@:2}")

  cd "$build_dir" || return 1

  if [ -f "pubspec.yaml" ]; then
    echo "Running: dart test ${args[*]}"
    if dart test "${args[@]}"; then
      mcount "test.success"
      return 0
    else
      mcount "test.failure"
      return 1
    fi
  else
    echo "No pubspec.yaml found"
    return 1
  fi
}

# Run format command
run_format() {
  local build_dir="$1"
  local args=("${@:2}")

  cd "$build_dir" || return 1

  if [ -f "pubspec.yaml" ]; then
    echo "Running: dart format ${args[*]}"
    if dart format "${args[@]}"; then
      mcount "format.success"
      return 0
    else
      mcount "format.failure"
      return 1
    fi
  else
    echo "No pubspec.yaml found"
    return 1
  fi
}

# Run doc command
run_doc() {
  local build_dir="$1"
  local args=("${@:2}")

  cd "$build_dir" || return 1

  if [ -f "pubspec.yaml" ]; then
    echo "Running: dart doc ${args[*]}"
    if dart doc "${args[@]}"; then
      mcount "doc.success"
      return 0
    else
      mcount "doc.failure"
      return 1
    fi
  else
    echo "No pubspec.yaml found"
    return 1
  fi
}

# Run compile command
run_compile() {
  local build_dir="$1"
  local target="$2"
  local output="$3"
  local args=("${@:4}")

  cd "$build_dir" || return 1

  if [ -f "pubspec.yaml" ]; then
    echo "Running: dart compile $target ${args[*]} -o $output"
    if dart compile "$target" "${args[@]}" -o "$output"; then
      mcount "compile.$target.success"
      return 0
    else
      mcount "compile.$target.failure"
      return 1
    fi
  else
    echo "No pubspec.yaml found"
    return 1
  fi
}

# Run pub global command
run_pub_global() {
  local build_dir="$1"
  local command="$2"
  local args=("${@:3}")

  cd "$build_dir" || return 1

  if [ -f "pubspec.yaml" ]; then
    echo "Running: dart pub global $command ${args[*]}"
    if dart pub global "$command" "${args[@]}"; then
      mcount "pub.global.$command.success"
      return 0
    else
      mcount "pub.global.$command.failure"
      return 1
    fi
  else
    echo "No pubspec.yaml found"
    return 1
  fi
}

# Run pub run command
run_pub_run() {
  local build_dir="$1"
  local command="$2"
  local args=("${@:3}")

  cd "$build_dir" || return 1

  if [ -f "pubspec.yaml" ]; then
    echo "Running: dart pub run $command ${args[*]}"
    if dart pub run "$command" "${args[@]}"; then
      mcount "pub.run.$command.success"
      return 0
    else
      mcount "pub.run.$command.failure"
      return 1
    fi
  else
    echo "No pubspec.yaml found"
    return 1
  fi
} 