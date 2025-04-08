#!/usr/bin/env bash

# shellcheck source=lib/vendor/stdlib_v7.sh
source "$BP_DIR/lib/vendor/stdlib_v7.sh"
# shellcheck source=lib/features.sh
source "$BP_DIR/lib/features.sh"
# shellcheck source=lib/json.sh
source "$BP_DIR/lib/json.sh"

# Log out information about the build that we can detect without accessing pubspec.yaml
log_initial_state() {
  meta_set "buildpack" "dart"
  meta_set "dart-package-manager" "pub"
  meta_set "has-dart-lock-file" "$(if [ -f "pubspec.lock" ]; then echo "true"; else echo "false"; fi)"
  meta_set "stack" "$STACK"

  # add any active features to the metadata set
  # prefix the key with "feature-"
  features_list | tr ' ' '\n' | while read -r key; do
    if [[ -n $key ]]; then
      meta_set "feature-$key" "$(features_get "$key")"
    fi
  done
}

# Log out information about the build that we can read from pubspec.yaml
log_project_info() {
  local time
  local build_dir="$1"

  # Does this project use "workspaces"?
  meta_set "uses-workspaces" "$(json::has_key "$build_dir/pubspec.yaml" "workspaces")"
  # What workspaces are defined? Logs as: `["packages/*","a","b"]`
  meta_set "workspaces" "$(json::read "$build_dir/pubspec.yaml" ".workspaces")"

  # just to be sure this isn't disruptive, let's time it. This can be removed later once we've
  # established that this is quick for all projects.
  time=$(nowms)
  # Count # of dart files to approximate project size, exclude any files in .dart_tool
  meta_set "num-project-files" "$(find "$build_dir" -name '*.dart' | grep -cv .dart_tool | tr -d '[:space:]')"
  meta_time "count-file-time" "$time"
}

generate_uuids() {
  # generate a unique id for each build
  meta_set "build-uuid" "$(uuid)"

  # propagate an app-uuid forward unless the cache is cleared
  if [[ -n "$(meta_prev_get "app-uuid")" ]]; then
    meta_set "app-uuid" "$(meta_prev_get "app-uuid")"
  else
    meta_set "app-uuid" "$(uuid)"
  fi
}

# Fonction pour enregistrer les données de build
# @param $1 build_dir - Répertoire de build
# @param $2 data - Données à enregistrer au format JSON
# @return 0 si l'enregistrement réussit, 1 sinon
log_build_data() {
  local build_dir="$1"
  local data="$2"
  local data_file="$build_dir/.dart-build-data.json"

  # Enregistre les données
  echo "$data" > "$data_file"

  return 0
}

# Fonction pour collecter les données de build
# @param $1 build_dir - Répertoire de build
# @return Les données de build au format JSON
collect_build_data() {
  local build_dir="$1"
  local data="{}"

  # Ajoute les informations de base
  data=$(echo "$data" | jq --arg version "$DART_VERSION" '. + {dart_version: $version}')
  data=$(echo "$data" | jq --arg env "$DART_ENV" '. + {dart_env: $env}')
  data=$(echo "$data" | jq --arg mode "$DART_BUILD_MODE" '. + {build_mode: $mode}')

  # Ajoute les informations de dépendances
  if [ -f "$build_dir/pubspec.lock" ]; then
    local deps
    deps=$(list_dependencies "$build_dir")
    data=$(echo "$data" | jq --argjson deps "$deps" '. + {dependencies: $deps}')
  fi

  # Ajoute les informations de performance
  local start_time
  start_time=$(date +%s)
  data=$(echo "$data" | jq --arg start_time "$start_time" '. + {start_time: $start_time}')

  echo "$data"
}

# Fonction pour analyser les performances du build
# @param $1 build_dir - Répertoire de build
# @return Les données de performance au format JSON
analyze_build_performance() {
  local build_dir="$1"
  local data_file="$build_dir/.dart-build-data.json"
  local performance_data="{}"

  if [ -f "$data_file" ]; then
    local start_time
    start_time=$(jq -r '.start_time' "$data_file")
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    performance_data=$(echo "$performance_data" | jq --arg duration "$duration" '. + {build_duration: $duration}')
  fi

  echo "$performance_data"
}

# Fonction pour générer un rapport de build
# @param $1 build_dir - Répertoire de build
# @return Le rapport de build au format JSON
generate_build_report() {
  local build_dir="$1"
  local report="{}"
  local build_data
  local performance_data

  # Collecte les données de build
  build_data=$(collect_build_data "$build_dir")

  # Analyse les performances
  performance_data=$(analyze_build_performance "$build_dir")

  # Combine les données
  report=$(echo "$report" | jq --argjson build_data "$build_data" '. + {build_data: $build_data}')
  report=$(echo "$report" | jq --argjson performance_data "$performance_data" '. + {performance_data: $performance_data}')

  echo "$report"
}

# Fonction pour sauvegarder le rapport de build
# @param $1 build_dir - Répertoire de build
# @param $2 report - Rapport à sauvegarder au format JSON
# @return 0 si la sauvegarde réussit, 1 sinon
save_build_report() {
  local build_dir="$1"
  local report="$2"
  local report_file="$build_dir/.dart-build-report.json"

  # Sauvegarde le rapport
  echo "$report" > "$report_file"

  return 0
}

# Fonction pour charger le rapport de build
# @param $1 build_dir - Répertoire de build
# @return Le rapport chargé ou un objet JSON vide si non trouvé
load_build_report() {
  local build_dir="$1"
  local report_file="$build_dir/.dart-build-report.json"

  if [ -f "$report_file" ]; then
    cat "$report_file"
  else
    echo "{}"
  fi
}

# Fonction pour mettre à jour le rapport de build
# @param $1 build_dir - Répertoire de build
# @param $2 updates - Mises à jour à appliquer au format JSON
# @return 0 si la mise à jour réussit, 1 sinon
update_build_report() {
  local build_dir="$1"
  local updates="$2"
  local current_report
  local new_report

  # Charge le rapport actuel
  current_report=$(load_build_report "$build_dir")

  # Applique les mises à jour
  new_report=$(echo "$current_report" | jq --argjson updates "$updates" '. + $updates')

  # Sauvegarde le nouveau rapport
  save_build_report "$build_dir" "$new_report"

  return 0
}

# Fonction pour obtenir une valeur du rapport
# @param $1 build_dir - Répertoire de build
# @param $2 key - Clé de la valeur à récupérer
# @return La valeur associée à la clé ou null si non trouvée
get_report_value() {
  local build_dir="$1"
  local key="$2"
  local report

  # Charge le rapport
  report=$(load_build_report "$build_dir")

  # Extrait la valeur
  echo "$report" | jq -r ".$key"
}

# Fonction pour définir une valeur dans le rapport
# @param $1 build_dir - Répertoire de build
# @param $2 key - Clé de la valeur à définir
# @param $3 value - Valeur à définir
# @return 0 si la définition réussit, 1 sinon
set_report_value() {
  local build_dir="$1"
  local key="$2"
  local value="$3"
  local updates="{\"$key\": \"$value\"}"

  # Met à jour le rapport
  update_build_report "$build_dir" "$updates"

  return 0
}

# Fonction pour supprimer une valeur du rapport
# @param $1 build_dir - Répertoire de build
# @param $2 key - Clé de la valeur à supprimer
# @return 0 si la suppression réussit, 1 sinon
delete_report_value() {
  local build_dir="$1"
  local key="$2"
  local current_report
  local new_report

  # Charge le rapport actuel
  current_report=$(load_build_report "$build_dir")

  # Supprime la valeur
  new_report=$(echo "$current_report" | jq "del(.$key)")

  # Sauvegarde le nouveau rapport
  save_build_report "$build_dir" "$new_report"

  return 0
}

# Fonction pour vérifier si une clé existe dans le rapport
# @param $1 build_dir - Répertoire de build
# @param $2 key - Clé à vérifier
# @return 0 si la clé existe, 1 sinon
has_report_key() {
  local build_dir="$1"
  local key="$2"
  local report

  # Charge le rapport
  report=$(load_build_report "$build_dir")

  # Vérifie si la clé existe
  if echo "$report" | jq -e ".$key" > /dev/null; then
    return 0
  else
    return 1
  fi
}

# Fonction pour lister toutes les clés du rapport
# @param $1 build_dir - Répertoire de build
# @return Liste des clés du rapport
list_report_keys() {
  local build_dir="$1"
  local report

  # Charge le rapport
  report=$(load_build_report "$build_dir")

  # Liste les clés
  echo "$report" | jq -r 'keys[]'
}

# Fonction pour effacer le rapport de build
# @param $1 build_dir - Répertoire de build
# @return 0 si l'effacement réussit, 1 sinon
clear_build_report() {
  local build_dir="$1"
  local report_file="$build_dir/.dart-build-report.json"

  # Supprime le fichier de rapport
  if [ -f "$report_file" ]; then
    rm "$report_file"
  fi

  return 0
}

# Track build metrics
track_build_metrics() {
  local build_dir="$1"
  local cache_dir="$2"
  local start_time="$3"
  local end_time="$4"

  # Track build duration
  mtime "build.duration" "$start_time" "$end_time"

  # Track dependencies count
  if [ -f "$build_dir/pubspec.lock" ]; then
    local deps_count=$(grep -c "^  " "$build_dir/pubspec.lock")
    mmeasure "dependencies.count" "$deps_count"
  fi

  # Track cache status
  if [ -d "$cache_dir/.pub-cache" ]; then
    mcount "cache.restored"
  else
    mcount "cache.new"
  fi

  # Track build mode
  mcount "build.mode.${DART_BUILD_MODE:-release}"

  # Track Dart version
  munique "dart.version" "$(dart --version | cut -d' ' -f2)"
}

# Save build data
save_build_data() {
  local build_dir="$1"
  local cache_dir="$2"
  local start_time="$3"
  local end_time="$4"
  local data_dir="$5"

  mkdir -p "$data_dir"
  
  # Save build data
  collect_build_data "$build_dir" "$cache_dir" > "$data_dir/build_data.txt"
  
  # Save performance data
  analyze_build_performance "$build_dir" "$start_time" "$end_time" > "$data_dir/performance_data.txt"
  
  # Generate and save build report
  generate_build_report "$build_dir" "$cache_dir" "$start_time" "$end_time" "$data_dir/build_report.txt"
  
  # Track metrics
  track_build_metrics "$build_dir" "$cache_dir" "$start_time" "$end_time"
}

# Log build information
log_build_info() {
  local build_dir="$1"
  local cache_dir="$2"
  local start_time="$3"

  # Log project information
  if [ -f "$build_dir/pubspec.yaml" ]; then
    local project_name
    local project_version
    local sdk_constraint

    project_name=$(yq -r '.name' "$build_dir/pubspec.yaml")
    project_version=$(yq -r '.version' "$build_dir/pubspec.yaml")
    sdk_constraint=$(yq -r '.environment.sdk' "$build_dir/pubspec.yaml")

    meta_set "project-name" "$project_name" "$cache_dir"
    meta_set "project-version" "$project_version" "$cache_dir"
    meta_set "sdk-constraint" "$sdk_constraint" "$cache_dir"
  fi

  # Log build information
  meta_set "build-id" "$(generate_uuid)" "$cache_dir"
  meta_set "build-start-time" "$start_time" "$cache_dir"
  meta_set "build-dir" "$build_dir" "$cache_dir"
  meta_set "cache-dir" "$cache_dir" "$cache_dir"
}

# Generate UUID
generate_uuid() {
  local uuid
  uuid=$(uuidgen)
  echo "${uuid,,}"
}

# Collect build data
collect_build_data() {
  local build_dir="$1"
  local cache_dir="$2"

  # Collect file information
  local dart_files
  local total_files
  local total_size

  dart_files=$(find "$build_dir" -type f -name "*.dart" | wc -l)
  total_files=$(find "$build_dir" -type f | wc -l)
  total_size=$(du -sb "$build_dir" | cut -f1)

  meta_set "dart-files" "$dart_files" "$cache_dir"
  meta_set "total-files" "$total_files" "$cache_dir"
  meta_set "total-size" "$total_size" "$cache_dir"

  # Collect dependency information
  if [ -f "$build_dir/pubspec.lock" ]; then
    local dependencies
    local dev_dependencies
    local total_dependencies

    dependencies=$(grep -c "^  " "$build_dir/pubspec.lock")
    dev_dependencies=$(grep -c "^  dev_dependencies:" "$build_dir/pubspec.yaml" || echo 0)
    total_dependencies=$((dependencies + dev_dependencies))

    meta_set "dependencies" "$dependencies" "$cache_dir"
    meta_set "dev-dependencies" "$dev_dependencies" "$cache_dir"
    meta_set "total-dependencies" "$total_dependencies" "$cache_dir"
  fi

  # Collect build configuration
  meta_set "build-mode" "${DART_BUILD_MODE:-release}" "$cache_dir"
  meta_set "build-flags" "${DART_BUILD_FLAGS:-}" "$cache_dir"
  meta_set "verbose-mode" "${DART_VERBOSE:-false}" "$cache_dir"
}

# Analyze build performance
analyze_build_performance() {
  local build_dir="$1"
  local cache_dir="$2"
  local start_time="$3"
  local end_time="$4"

  # Calculate build duration
  local duration
  duration=$((end_time - start_time))
  meta_set "build-duration" "$duration" "$cache_dir"

  # Calculate build speed
  local total_size
  total_size=$(meta_get "total-size" "$cache_dir")
  if [ -n "$total_size" ] && [ "$duration" -gt 0 ]; then
    local speed
    speed=$((total_size / duration))
    meta_set "build-speed" "$speed" "$cache_dir"
  fi

  # Calculate cache efficiency
  local cache_hits
  local cache_misses
  cache_hits=$(meta_get "cache-hits" "$cache_dir" || echo 0)
  cache_misses=$(meta_get "cache-misses" "$cache_dir" || echo 0)
  local total_cache_attempts
  total_cache_attempts=$((cache_hits + cache_misses))
  if [ "$total_cache_attempts" -gt 0 ]; then
    local cache_efficiency
    cache_efficiency=$((cache_hits * 100 / total_cache_attempts))
    meta_set "cache-efficiency" "$cache_efficiency" "$cache_dir"
  fi
}

# Generate build report
generate_build_report() {
  local build_dir="$1"
  local cache_dir="$2"

  echo "Build Report"
  echo "==========="
  echo "Project: $(meta_get "project-name" "$cache_dir") v$(meta_get "project-version" "$cache_dir")"
  echo "Build ID: $(meta_get "build-id" "$cache_dir")"
  echo "Build Mode: $(meta_get "build-mode" "$cache_dir")"
  echo "Build Duration: $(meta_get "build-duration" "$cache_dir")s"
  echo "Build Speed: $(numfmt --to=iec "$(meta_get "build-speed" "$cache_dir")")/s"
  echo "Cache Efficiency: $(meta_get "cache-efficiency" "$cache_dir")%"
  echo ""
  echo "Files:"
  echo "  Dart Files: $(meta_get "dart-files" "$cache_dir")"
  echo "  Total Files: $(meta_get "total-files" "$cache_dir")"
  echo "  Total Size: $(numfmt --to=iec "$(meta_get "total-size" "$cache_dir")")"
  echo ""
  echo "Dependencies:"
  echo "  Dependencies: $(meta_get "dependencies" "$cache_dir")"
  echo "  Dev Dependencies: $(meta_get "dev-dependencies" "$cache_dir")"
  echo "  Total Dependencies: $(meta_get "total-dependencies" "$cache_dir")"
}

# Track build metrics
track_build_metrics() {
  local build_dir="$1"
  local cache_dir="$2"
  local metric="$3"
  local value="$4"

  meta_set "metric-$metric" "$value" "$cache_dir"
}

# Save build data
save_build_data() {
  local build_dir="$1"
  local cache_dir="$2"
  local output_file="$3"

  if [ -f "$cache_dir/dart/metadata.json" ]; then
    cp "$cache_dir/dart/metadata.json" "$output_file"
  fi
}

# Load build data
load_build_data() {
  local build_dir="$1"
  local cache_dir="$2"
  local input_file="$3"

  if [ -f "$input_file" ]; then
    mkdir -p "$cache_dir/dart"
    cp "$input_file" "$cache_dir/dart/metadata.json"
  fi
}

# Clear build data
clear_build_data() {
  local cache_dir="$1"

  rm -f "$cache_dir/dart/metadata.json"
}

# Get build data
get_build_data() {
  local cache_dir="$1"
  local key="$2"

  meta_get "$key" "$cache_dir"
}

# Set build data
set_build_data() {
  local cache_dir="$1"
  local key="$2"
  local value="$3"

  meta_set "$key" "$value" "$cache_dir"
}

# Check build data
check_build_data() {
  local cache_dir="$1"
  local key="$2"

  has_metadata "$key" "$cache_dir"
}

# Get all build data
get_all_build_data() {
  local cache_dir="$1"

  get_all_metadata "$cache_dir"
}
