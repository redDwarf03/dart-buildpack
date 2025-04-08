#!/usr/bin/env bash

# shellcheck source=lib/vendor/stdlib_v7.sh
source "$BP_DIR/lib/vendor/stdlib_v7.sh"

# Fonction pour créer une signature de cache
# @param $1 build_dir - Répertoire de build
# @return La signature du cache
create_signature() {
  local build_dir="$1"
  local signature=""

  # Crée une signature basée sur l'environnement et les packages
  if [ -f "$build_dir/pubspec.yaml" ]; then
    signature=$(cat "$build_dir/pubspec.yaml" | md5sum | cut -d' ' -f1)
  fi

  # Ajoute la version de Dart à la signature
  if command -v dart >/dev/null; then
    signature="$signature-$(dart --version | md5sum | cut -d' ' -f1)"
  fi

  echo "$signature"
}

# Fonction pour sauvegarder la signature du cache
# @param $1 build_dir - Répertoire de build
# @param $2 signature - Signature à sauvegarder
# @return 0 si la sauvegarde réussit, 1 sinon
save_signature() {
  local build_dir="$1"
  local signature="$2"

  echo "$signature" > "$build_dir/.cache-signature"
  return $?
}

# Fonction pour charger la signature du cache
# @param $1 build_dir - Répertoire de build
# @return La signature du cache ou une chaîne vide si non trouvée
load_signature() {
  local build_dir="$1"

  if [ -f "$build_dir/.cache-signature" ]; then
    cat "$build_dir/.cache-signature"
  else
    echo ""
  fi
}

# Fonction pour obtenir le statut du cache
# @param $1 build_dir - Répertoire de build
# @return 0 si le cache est valide, 1 sinon
get_cache_status() {
  local build_dir="$1"
  local current_signature
  local saved_signature

  current_signature=$(create_signature "$build_dir")
  saved_signature=$(load_signature "$build_dir")

  if [ "$current_signature" = "$saved_signature" ]; then
    return 0
  else
    return 1
  fi
}

# Fonction pour obtenir les répertoires à mettre en cache
# @param $1 build_dir - Répertoire de build
# @return Liste des répertoires à mettre en cache
get_cache_directories() {
  local build_dir="$1"
  local directories=()

  # Ajoute le cache pub
  if [ -d "$build_dir/.pub-cache" ]; then
    directories+=("$build_dir/.pub-cache")
  fi

  # Ajoute le répertoire .dart_tool
  if [ -d "$build_dir/.dart_tool" ]; then
    directories+=("$build_dir/.dart_tool")
  fi

  echo "${directories[@]}"
}

# Fonction pour sauvegarder les répertoires en cache
# @param $1 build_dir - Répertoire de build
# @param $2 cache_dir - Répertoire de cache
# @return 0 si la sauvegarde réussit, 1 sinon
save_cache_directories() {
  local build_dir="$1"
  local cache_dir="$2"
  local directories
  local directory

  directories=($(get_cache_directories "$build_dir"))

  for directory in "${directories[@]}"; do
    if [ -d "$directory" ]; then
      mkdir -p "$cache_dir/$(basename "$directory")"
      cp -r "$directory"/* "$cache_dir/$(basename "$directory")/"
    fi
  done

  return 0
}

# Fonction pour restaurer les répertoires depuis le cache
# @param $1 build_dir - Répertoire de build
# @param $2 cache_dir - Répertoire de cache
# @return 0 si la restauration réussit, 1 sinon
restore_cache_directories() {
  local build_dir="$1"
  local cache_dir="$2"
  local directories
  local directory

  directories=($(get_cache_directories "$build_dir"))

  for directory in "${directories[@]}"; do
    if [ -d "$cache_dir/$(basename "$directory")" ]; then
      mkdir -p "$directory"
      cp -r "$cache_dir/$(basename "$directory")"/* "$directory/"
    fi
  done

  return 0
}

# Fonction pour effacer le cache
# @param $1 build_dir - Répertoire de build
# @return 0 si l'effacement réussit, 1 sinon
clear_cache() {
  local build_dir="$1"
  local directories
  local directory

  directories=($(get_cache_directories "$build_dir"))

  for directory in "${directories[@]}"; do
    if [ -d "$directory" ]; then
      rm -rf "$directory"
    fi
  done

  return 0
}

# Fonction pour vérifier la taille du cache
# @param $1 build_dir - Répertoire de build
# @param $2 max_size - Taille maximale en octets
# @return 0 si la taille est acceptable, 1 sinon
check_cache_size() {
  local build_dir="$1"
  local max_size="$2"
  local directories
  local directory
  local total_size=0

  directories=($(get_cache_directories "$build_dir"))

  for directory in "${directories[@]}"; do
    if [ -d "$directory" ]; then
      total_size=$((total_size + $(du -sb "$directory" | cut -f1)))
    fi
  done

  if [ "$total_size" -gt "$max_size" ]; then
    return 1
  else
    return 0
  fi
}

# Fonction pour nettoyer le cache
# @param $1 build_dir - Répertoire de build
# @param $2 max_size - Taille maximale en octets
# @return 0 si le nettoyage réussit, 1 sinon
prune_cache() {
  local build_dir="$1"
  local max_size="$2"

  while ! check_cache_size "$build_dir" "$max_size"; do
    # Supprime les fichiers les plus anciens
    find "$build_dir/.pub-cache" -type f -printf '%T+ %p\n' | sort | head -n 100 | cut -d' ' -f2- | xargs rm -f
  done

  return 0
}

# Fonction pour obtenir les métadonnées du cache
# @param $1 build_dir - Répertoire de build
# @return Les métadonnées du cache au format JSON
get_cache_metadata() {
  local build_dir="$1"
  local metadata="{}"
  local directories
  local directory
  local sizes=()

  directories=($(get_cache_directories "$build_dir"))

  for directory in "${directories[@]}"; do
    if [ -d "$directory" ]; then
      sizes+=("$(basename "$directory"):$(du -sb "$directory" | cut -f1)")
    fi
  done

  metadata=$(jq -n \
    --arg signature "$(load_signature "$build_dir")" \
    --argjson sizes "$(printf '%s\n' "${sizes[@]}" | jq -R . | jq -s .)" \
    '{
      "signature": $signature,
      "sizes": $sizes
    }')

  echo "$metadata"
}

# Fonction pour sauvegarder les métadonnées du cache
# @param $1 build_dir - Répertoire de build
# @param $2 metadata - Métadonnées à sauvegarder
# @return 0 si la sauvegarde réussit, 1 sinon
save_cache_metadata() {
  local build_dir="$1"
  local metadata="$2"

  echo "$metadata" > "$build_dir/.cache-metadata"
  return $?
}

# Fonction pour charger les métadonnées du cache
# @param $1 build_dir - Répertoire de build
# @return Les métadonnées du cache ou un objet JSON vide si non trouvées
load_cache_metadata() {
  local build_dir="$1"

  if [ -f "$build_dir/.cache-metadata" ]; then
    cat "$build_dir/.cache-metadata"
  else
    echo "{}"
  fi
}

# Fonction pour vérifier l'intégrité du cache
# @param $1 build_dir - Répertoire de build
# @return 0 si l'intégrité est valide, 1 sinon
verify_cache_integrity() {
  local build_dir="$1"
  local metadata
  local directories
  local directory

  metadata=$(load_cache_metadata "$build_dir")
  directories=($(get_cache_directories "$build_dir"))

  for directory in "${directories[@]}"; do
    if [ -d "$directory" ]; then
      local size
      size=$(du -sb "$directory" | cut -f1)
      local expected_size
      expected_size=$(echo "$metadata" | jq -r ".sizes[] | select(startswith(\"$(basename "$directory")\")) | split(\":\")[1]")

      if [ "$size" != "$expected_size" ]; then
        return 1
      fi
    fi
  done

  return 0
}
