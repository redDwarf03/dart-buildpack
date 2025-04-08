#!/usr/bin/env bash

# shellcheck source=lib/vendor/stdlib_v7.sh
source "$BP_DIR/lib/vendor/stdlib_v7.sh"

# Fonction pour mesurer la taille d'un répertoire
# @param $1 directory - Répertoire à mesurer
# @return La taille du répertoire en octets
measure_size() {
  local directory="$1"
  du -sb "$directory" | cut -f1
}

# Fonction pour lister les dépendances depuis pubspec.lock
# @param $1 build_dir - Répertoire de build
# @return Liste des dépendances au format JSON
list_dependencies() {
  local build_dir="$1"
  local deps="[]"

  if [ -f "$build_dir/pubspec.lock" ]; then
    deps=$(dart pub deps --json | jq '.packages')
  fi

  echo "$deps"
}

# Fonction pour exécuter un script Dart
# @param $1 build_dir - Répertoire de build
# @param $2 script - Script à exécuter
# @return 0 si l'exécution réussit, 1 sinon
run_dart_script() {
  local build_dir="$1"
  local script="$2"

  cd "$build_dir" || return 1
  dart "$script"
  return $?
}

# Fonction pour exécuter dart pub get
# @param $1 build_dir - Répertoire de build
# @return 0 si l'installation réussit, 1 sinon
run_pub_get() {
  local build_dir="$1"

  cd "$build_dir" || return 1
  dart pub get
  return $?
}

# Fonction pour exécuter dart pub upgrade
# @param $1 build_dir - Répertoire de build
# @return 0 si la mise à jour réussit, 1 sinon
run_pub_upgrade() {
  local build_dir="$1"

  cd "$build_dir" || return 1
  dart pub upgrade
  return $?
}

# Fonction pour exécuter dart pub outdated
# @param $1 build_dir - Répertoire de build
# @return Liste des dépendances obsolètes au format JSON
run_pub_outdated() {
  local build_dir="$1"
  local outdated="[]"

  cd "$build_dir" || return 1
  outdated=$(dart pub outdated --json)
  echo "$outdated"
}

# Fonction pour exécuter dart analyze
# @param $1 build_dir - Répertoire de build
# @return 0 si l'analyse réussit, 1 sinon
run_dart_analyze() {
  local build_dir="$1"

  cd "$build_dir" || return 1
  dart analyze
  return $?
}

# Fonction pour exécuter dart test
# @param $1 build_dir - Répertoire de build
# @return 0 si les tests réussissent, 1 sinon
run_dart_test() {
  local build_dir="$1"

  cd "$build_dir" || return 1
  dart test
  return $?
}

# Fonction pour exécuter dart compile
# @param $1 build_dir - Répertoire de build
# @param $2 target - Cible de compilation
# @return 0 si la compilation réussit, 1 sinon
run_dart_compile() {
  local build_dir="$1"
  local target="$2"

  cd "$build_dir" || return 1
  dart compile "$target"
  return $?
}

# Fonction pour exécuter build_runner
# @param $1 build_dir - Répertoire de build
# @param $2 command - Commande build_runner à exécuter
# @return 0 si l'exécution réussit, 1 sinon
run_build_runner() {
  local build_dir="$1"
  local command="$2"

  cd "$build_dir" || return 1
  dart run build_runner "$command"
  return $?
}

# Fonction pour vérifier les dépendances
# @param $1 build_dir - Répertoire de build
# @return 0 si les dépendances sont valides, 1 sinon
check_dependencies() {
  local build_dir="$1"
  local missing_deps=0
  local outdated_deps=0

  # Vérifie les dépendances manquantes
  if ! run_pub_get "$build_dir"; then
    missing_deps=1
  fi

  # Vérifie les dépendances obsolètes
  local outdated
  outdated=$(run_pub_outdated "$build_dir")
  if [ "$(echo "$outdated" | jq 'length')" -gt 0 ]; then
    outdated_deps=1
  fi

  if [ "$missing_deps" -eq 1 ] || [ "$outdated_deps" -eq 1 ]; then
    return 1
  fi

  return 0
}

# Fonction pour installer les dépendances
# @param $1 build_dir - Répertoire de build
# @return 0 si l'installation réussit, 1 sinon
install_dependencies() {
  local build_dir="$1"

  # Installe les dépendances
  if ! run_pub_get "$build_dir"; then
    return 1
  fi

  # Vérifie les dépendances
  if ! check_dependencies "$build_dir"; then
    return 1
  fi

  return 0
}

# Fonction pour nettoyer les dépendances
# @param $1 build_dir - Répertoire de build
# @return 0 si le nettoyage réussit, 1 sinon
clean_dependencies() {
  local build_dir="$1"

  # Nettoie les artefacts de build
  if [ -d "$build_dir/build" ]; then
    rm -rf "$build_dir/build"
  fi

  # Nettoie le cache pub
  if [ -d "$build_dir/.dart_tool" ]; then
    rm -rf "$build_dir/.dart_tool"
  fi

  return 0
}

# Fonction pour restaurer le cache
# @param $1 build_dir - Répertoire de build
# @param $2 cache_dir - Répertoire de cache
# @return 0 si la restauration réussit, 1 sinon
restore_cache() {
  local build_dir="$1"
  local cache_dir="$2"

  if [ -d "$cache_dir/.pub-cache" ]; then
    mkdir -p "$build_dir/.pub-cache"
    cp -r "$cache_dir/.pub-cache"/* "$build_dir/.pub-cache/"
  fi

  return 0
}

# Fonction pour sauvegarder le cache
# @param $1 build_dir - Répertoire de build
# @param $2 cache_dir - Répertoire de cache
# @return 0 si la sauvegarde réussit, 1 sinon
save_cache() {
  local build_dir="$1"
  local cache_dir="$2"

  if [ -d "$build_dir/.pub-cache" ]; then
    mkdir -p "$cache_dir/.pub-cache"
    cp -r "$build_dir/.pub-cache"/* "$cache_dir/.pub-cache/"
  fi

  return 0
}
