#!/usr/bin/env bash

# shellcheck source=lib/vendor/stdlib_v7.sh
source "$BP_DIR/lib/vendor/stdlib_v7.sh"
# shellcheck source=lib/features.sh
source "$BP_DIR/lib/features.sh"
# shellcheck source=lib/uuid.sh
source "$BP_DIR/lib/uuid.sh"

# Set metadata value (alias for set_metadata)
meta_set() {
  set_metadata "$@"
}

# variable shared by this whole module
BUILD_DATA_FILE=""
PREVIOUS_BUILD_DATA_FILE=""

# Initialize metadata
init_metadata() {
  mkdir -p "$CACHE_DIR/dart/metadata"
  touch "$CACHE_DIR/dart/metadata.json"
}

# Setup metadata
setup_metadata() {
  local build_dir="$1"
  local cache_dir="$2"

  # Initialize metadata directory
  mkdir -p "$cache_dir/dart/metadata"

  # Create metadata file if it doesn't exist
  if [ ! -f "$cache_dir/dart/metadata.json" ]; then
    echo "{}" > "$cache_dir/dart/metadata.json"
  fi

  # Set initial metadata
  set_metadata "buildpack" "dart" "$cache_dir"
  set_metadata "buildpack-version" "$BUILDPACK_VERSION" "$cache_dir"
  set_metadata "stack" "$STACK" "$cache_dir"

  # Set Dart specific metadata
  if [ -f "$build_dir/pubspec.yaml" ]; then
    set_metadata "project-name" "$(yq -r '.name' "$build_dir/pubspec.yaml")" "$cache_dir"
    set_metadata "project-version" "$(yq -r '.version' "$build_dir/pubspec.yaml")" "$cache_dir"
    set_metadata "sdk-constraint" "$(yq -r '.environment.sdk' "$build_dir/pubspec.yaml")" "$cache_dir"
  fi

  # Set build metadata
  set_metadata "build-id" "$(uuid)" "$cache_dir"
  set_metadata "build-time" "$(date +%s)" "$cache_dir"
  set_metadata "build-mode" "${DART_BUILD_MODE:-release}" "$cache_dir"
}

# Get metadata
get_metadata() {
  local key="$1"
  local cache_dir="$2"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq -r --arg key "$key" '.[$key]' "$metadata_file"
  fi
}

# Set metadata
set_metadata() {
  local key="$1"
  local value="$2"
  local cache_dir="$3"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    # Initialize file if empty
    if [ ! -s "$metadata_file" ]; then
      echo "{}" > "$metadata_file"
    fi
    
    # Use --arg for both key and value to handle all types safely
    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$metadata_file" > "$metadata_file.tmp"
    mv "$metadata_file.tmp" "$metadata_file"
  fi
}

# Has metadata
has_metadata() {
  local key="$1"
  local cache_dir="$2"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq --arg key "$key" 'has($key)' "$metadata_file" | grep -q "true"
  else
    return 1
  fi
}

# Get all metadata
get_all_metadata() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    cat "$metadata_file"
  else
    echo "{}"
  fi
}

# Clear metadata
clear_metadata() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    echo "{}" > "$metadata_file"
  fi
}

# Save metadata
save_metadata() {
  local cache_dir="$1"
  local output_file="$2"

  if [ -f "$cache_dir/dart/metadata.json" ]; then
    cp "$cache_dir/dart/metadata.json" "$output_file"
  fi
}

# Load metadata
load_metadata() {
  local cache_dir="$1"
  local input_file="$2"

  if [ -f "$input_file" ]; then
    mkdir -p "$cache_dir/dart"
    cp "$input_file" "$cache_dir/dart/metadata.json"
  fi
}

# Update metadata
update_metadata() {
  local key="$1"
  local value="$2"
  local cache_dir="$3"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$metadata_file" > "$metadata_file.tmp"
    mv "$metadata_file.tmp" "$metadata_file"
  fi
}

# Remove metadata
remove_metadata() {
  local key="$1"
  local cache_dir="$2"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq --arg key "$key" 'del(.[$key])' "$metadata_file" > "$metadata_file.tmp"
    mv "$metadata_file.tmp" "$metadata_file"
  fi
}

# Get metadata keys
get_metadata_keys() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq 'keys[]' "$metadata_file" | tr -d '"'
  fi
}

# Get metadata values
get_metadata_values() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq '.[]' "$metadata_file" | tr -d '"'
  fi
}

# Get metadata count
get_metadata_count() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq 'length' "$metadata_file"
  else
    echo "0"
  fi
}

# Check metadata file
check_metadata_file() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    if jq empty "$metadata_file" >/dev/null 2>&1; then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

# Repair metadata file
repair_metadata_file() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    if ! jq empty "$metadata_file" >/dev/null 2>&1; then
      echo "{}" > "$metadata_file"
    fi
  fi
}

# Backup metadata
backup_metadata() {
  local cache_dir="$1"
  local backup_dir="$2"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    mkdir -p "$backup_dir"
    cp "$metadata_file" "$backup_dir/metadata.json"
  fi
}

# Restore metadata
restore_metadata() {
  local cache_dir="$1"
  local backup_dir="$2"
  local backup_file="$backup_dir/metadata.json"

  if [ -f "$backup_file" ]; then
    mkdir -p "$cache_dir/dart"
    cp "$backup_file" "$cache_dir/dart/metadata.json"
  fi
}

# Export metadata
export_metadata() {
  local cache_dir="$1"
  local output_file="$2"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    cp "$metadata_file" "$output_file"
  fi
}

# Import metadata
import_metadata() {
  local cache_dir="$1"
  local input_file="$2"

  if [ -f "$input_file" ]; then
    mkdir -p "$cache_dir/dart"
    cp "$input_file" "$cache_dir/dart/metadata.json"
  fi
}

# Merge metadata
merge_metadata() {
  local cache_dir="$1"
  local input_file="$2"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ] && [ -f "$input_file" ]; then
    jq -s '.[0] * .[1]' "$metadata_file" "$input_file" > "$metadata_file.tmp"
    mv "$metadata_file.tmp" "$metadata_file"
  fi
}

# Filter metadata
filter_metadata() {
  local cache_dir="$1"
  local pattern="$2"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq --arg pattern "$pattern" 'to_entries | map(select(.key | test($pattern))) | from_entries' "$metadata_file"
  fi
}

# Sort metadata
sort_metadata() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq -S '.' "$metadata_file" > "$metadata_file.tmp"
    mv "$metadata_file.tmp" "$metadata_file"
  fi
}

# Validate metadata
validate_metadata() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    if jq empty "$metadata_file" >/dev/null 2>&1; then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

# Clean metadata
clean_metadata() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq 'del(.[] | select(. == null or . == ""))' "$metadata_file" > "$metadata_file.tmp"
    mv "$metadata_file.tmp" "$metadata_file"
  fi
}

# Format metadata
format_metadata() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq '.' "$metadata_file" > "$metadata_file.tmp"
    mv "$metadata_file.tmp" "$metadata_file"
  fi
}

# Get metadata size
get_metadata_size() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    du -b "$metadata_file" | cut -f1
  else
    echo "0"
  fi
}

# Get metadata age
get_metadata_age() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    local now
    local file_time
    now=$(date +%s)
    file_time=$(stat -f %m "$metadata_file")
    echo $((now - file_time))
  else
    echo "0"
  fi
}

# Get metadata type
get_metadata_type() {
  local cache_dir="$1"
  local key="$2"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    jq --arg key "$key" '.[$key] | type' "$metadata_file" | tr -d '"'
  fi
}

# Get metadata path
get_metadata_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.json"
}

# Get metadata dir
get_metadata_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart"
}

# Get metadata backup path
get_metadata_backup_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.json.bak"
}

# Get metadata backup dir
get_metadata_backup_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup"
}

# Get metadata temp path
get_metadata_temp_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.json.tmp"
}

# Get metadata temp dir
get_metadata_temp_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/temp"
}

# Get metadata log path
get_metadata_log_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.log"
}

# Get metadata log dir
get_metadata_log_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/logs"
}

# Get metadata error path
get_metadata_error_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.err"
}

# Get metadata error dir
get_metadata_error_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/errors"
}

# Get metadata debug path
get_metadata_debug_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.debug"
}

# Get metadata debug dir
get_metadata_debug_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/debug"
}

# Get metadata info path
get_metadata_info_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.info"
}

# Get metadata info dir
get_metadata_info_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/info"
}

# Get metadata warn path
get_metadata_warn_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.warn"
}

# Get metadata warn dir
get_metadata_warn_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/warnings"
}

# Get metadata fatal path
get_metadata_fatal_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.fatal"
}

# Get metadata fatal dir
get_metadata_fatal_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/fatal"
}

# Get metadata trace path
get_metadata_trace_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.trace"
}

# Get metadata trace dir
get_metadata_trace_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/trace"
}

# Get metadata audit path
get_metadata_audit_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.audit"
}

# Get metadata audit dir
get_metadata_audit_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/audit"
}

# Get metadata security path
get_metadata_security_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.security"
}

# Get metadata security dir
get_metadata_security_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/security"
}

# Get metadata performance path
get_metadata_performance_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.performance"
}

# Get metadata performance dir
get_metadata_performance_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/performance"
}

# Get metadata metrics path
get_metadata_metrics_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.metrics"
}

# Get metadata metrics dir
get_metadata_metrics_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metrics"
}

# Get metadata stats path
get_metadata_stats_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.stats"
}

# Get metadata stats dir
get_metadata_stats_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/stats"
}

# Get metadata report path
get_metadata_report_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.report"
}

# Get metadata report dir
get_metadata_report_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/reports"
}

# Get metadata summary path
get_metadata_summary_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.summary"
}

# Get metadata summary dir
get_metadata_summary_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/summaries"
}

# Get metadata history path
get_metadata_history_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.history"
}

# Get metadata history dir
get_metadata_history_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/history"
}

# Get metadata archive path
get_metadata_archive_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.archive"
}

# Get metadata archive dir
get_metadata_archive_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/archives"
}

# Get metadata backup history path
get_metadata_backup_history_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.history"
}

# Get metadata backup history dir
get_metadata_backup_history_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/history"
}

# Get metadata backup archive path
get_metadata_backup_archive_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.archive"
}

# Get metadata backup archive dir
get_metadata_backup_archive_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/archives"
}

# Get metadata backup temp path
get_metadata_backup_temp_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.temp"
}

# Get metadata backup temp dir
get_metadata_backup_temp_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/temp"
}

# Get metadata backup log path
get_metadata_backup_log_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.log"
}

# Get metadata backup log dir
get_metadata_backup_log_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/logs"
}

# Get metadata backup error path
get_metadata_backup_error_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.err"
}

# Get metadata backup error dir
get_metadata_backup_error_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/errors"
}

# Get metadata backup debug path
get_metadata_backup_debug_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.debug"
}

# Get metadata backup debug dir
get_metadata_backup_debug_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/debug"
}

# Get metadata backup info path
get_metadata_backup_info_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.info"
}

# Get metadata backup info dir
get_metadata_backup_info_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/info"
}

# Get metadata backup warn path
get_metadata_backup_warn_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.warn"
}

# Get metadata backup warn dir
get_metadata_backup_warn_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/warnings"
}

# Get metadata backup fatal path
get_metadata_backup_fatal_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.fatal"
}

# Get metadata backup fatal dir
get_metadata_backup_fatal_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/fatal"
}

# Get metadata backup trace path
get_metadata_backup_trace_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.trace"
}

# Get metadata backup trace dir
get_metadata_backup_trace_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/trace"
}

# Get metadata backup audit path
get_metadata_backup_audit_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.audit"
}

# Get metadata backup audit dir
get_metadata_backup_audit_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/audit"
}

# Get metadata backup security path
get_metadata_backup_security_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.security"
}

# Get metadata backup security dir
get_metadata_backup_security_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/security"
}

# Get metadata backup performance path
get_metadata_backup_performance_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.performance"
}

# Get metadata backup performance dir
get_metadata_backup_performance_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/performance"
}

# Get metadata backup metrics path
get_metadata_backup_metrics_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.metrics"
}

# Get metadata backup metrics dir
get_metadata_backup_metrics_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/metrics"
}

# Get metadata backup stats path
get_metadata_backup_stats_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.stats"
}

# Get metadata backup stats dir
get_metadata_backup_stats_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/stats"
}

# Get metadata backup report path
get_metadata_backup_report_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.report"
}

# Get metadata backup report dir
get_metadata_backup_report_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/reports"
}

# Get metadata backup summary path
get_metadata_backup_summary_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.summary"
}

# Get metadata backup summary dir
get_metadata_backup_summary_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/summaries"
}

# Get metadata backup history path
get_metadata_backup_history_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.history"
}

# Get metadata backup history dir
get_metadata_backup_history_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/history"
}

# Get metadata backup archive path
get_metadata_backup_archive_path() {
  local cache_dir="$1"
  echo "$cache_dir/dart/metadata.backup.archive"
}

# Get metadata backup archive dir
get_metadata_backup_archive_dir() {
  local cache_dir="$1"
  echo "$cache_dir/dart/backup/archives"
}

# Fonction pour créer les métadonnées du build
# @param $1 build_dir - Répertoire de build
# @return Les métadonnées du build au format JSON
create_build_metadata() {
  local build_dir="$1"
  local metadata="{}"

  # Ajoute les informations de base
  metadata=$(echo "$metadata" | jq --arg version "$DART_VERSION" '. + {dart_version: $version}')
  metadata=$(echo "$metadata" | jq --arg env "$DART_ENV" '. + {dart_env: $env}')
  metadata=$(echo "$metadata" | jq --arg mode "$DART_BUILD_MODE" '. + {build_mode: $mode}')

  # Ajoute les informations de dépendances
  if [ -f "$build_dir/pubspec.lock" ]; then
    local deps
    deps=$(list_dependencies "$build_dir")
    metadata=$(echo "$metadata" | jq --argjson deps "$deps" '. + {dependencies: $deps}')
  fi

  echo "$metadata"
}

# Fonction pour sauvegarder les métadonnées du build
# @param $1 build_dir - Répertoire de build
# @param $2 metadata - Métadonnées à sauvegarder
# @return 0 si la sauvegarde réussit, 1 sinon
save_build_metadata() {
  local build_dir="$1"
  local metadata="$2"
  local metadata_file="$build_dir/.dart-build-metadata.json"

  # Sauvegarde les métadonnées
  echo "$metadata" > "$metadata_file"

  return 0
}

# Fonction pour charger les métadonnées du build
# @param $1 build_dir - Répertoire de build
# @return Les métadonnées chargées ou un objet JSON vide si non trouvées
load_build_metadata() {
  local build_dir="$1"
  local metadata_file="$build_dir/.dart-build-metadata.json"

  if [ -f "$metadata_file" ]; then
    cat "$metadata_file"
  else
    echo "{}"
  fi
}

# Fonction pour mettre à jour les métadonnées du build
# @param $1 build_dir - Répertoire de build
# @param $2 updates - Mises à jour à appliquer au format JSON
# @return 0 si la mise à jour réussit, 1 sinon
update_build_metadata() {
  local build_dir="$1"
  local updates="$2"
  local current_metadata
  local new_metadata

  # Charge les métadonnées actuelles
  current_metadata=$(load_build_metadata "$build_dir")

  # Applique les mises à jour
  new_metadata=$(echo "$current_metadata" | jq --argjson updates "$updates" '. + $updates')

  # Sauvegarde les nouvelles métadonnées
  save_build_metadata "$build_dir" "$new_metadata"

  return 0
}

# Fonction pour obtenir une valeur des métadonnées
# @param $1 build_dir - Répertoire de build
# @param $2 key - Clé de la valeur à récupérer
# @return La valeur associée à la clé ou null si non trouvée
get_metadata_value() {
  local build_dir="$1"
  local key="$2"
  local metadata

  # Charge les métadonnées
  metadata=$(load_build_metadata "$build_dir")

  # Extrait la valeur
  echo "$metadata" | jq -r ".$key"
}

# Fonction pour définir une valeur dans les métadonnées
# @param $1 build_dir - Répertoire de build
# @param $2 key - Clé de la valeur à définir
# @param $3 value - Valeur à définir
# @return 0 si la définition réussit, 1 sinon
set_metadata_value() {
  local build_dir="$1"
  local key="$2"
  local value="$3"
  local updates="{\"$key\": \"$value\"}"

  # Met à jour les métadonnées
  update_build_metadata "$build_dir" "$updates"

  return 0
}

# Fonction pour supprimer une valeur des métadonnées
# @param $1 build_dir - Répertoire de build
# @param $2 key - Clé de la valeur à supprimer
# @return 0 si la suppression réussit, 1 sinon
delete_metadata_value() {
  local build_dir="$1"
  local key="$2"
  local current_metadata
  local new_metadata

  # Charge les métadonnées actuelles
  current_metadata=$(load_build_metadata "$build_dir")

  # Supprime la valeur
  new_metadata=$(echo "$current_metadata" | jq "del(.$key)")

  # Sauvegarde les nouvelles métadonnées
  save_build_metadata "$build_dir" "$new_metadata"

  return 0
}

# Fonction pour vérifier si une clé existe dans les métadonnées
# @param $1 build_dir - Répertoire de build
# @param $2 key - Clé à vérifier
# @return 0 si la clé existe, 1 sinon
has_metadata_key() {
  local build_dir="$1"
  local key="$2"
  local metadata

  # Charge les métadonnées
  metadata=$(load_build_metadata "$build_dir")

  # Vérifie si la clé existe
  if echo "$metadata" | jq -e ".$key" > /dev/null; then
    return 0
  else
    return 1
  fi
}

# Fonction pour lister toutes les clés des métadonnées
# @param $1 build_dir - Répertoire de build
# @return Liste des clés des métadonnées
list_metadata_keys() {
  local build_dir="$1"
  local metadata

  # Charge les métadonnées
  metadata=$(load_build_metadata "$build_dir")

  # Liste les clés
  echo "$metadata" | jq -r 'keys[]'
}

# Fonction pour effacer toutes les métadonnées
# @param $1 build_dir - Répertoire de build
# @return 0 si l'effacement réussit, 1 sinon
clear_metadata() {
  local build_dir="$1"
  local metadata_file="$build_dir/.dart-build-metadata.json"

  # Supprime le fichier de métadonnées
  if [ -f "$metadata_file" ]; then
    rm "$metadata_file"
  fi

  return 0
}

# Log metadata in a formatted way
log_meta_data() {
  local cache_dir="$1"
  local metadata_file="$cache_dir/dart/metadata.json"

  if [ -f "$metadata_file" ]; then
    echo "-----> Metadata:"
    jq -r 'to_entries | .[] | "       \(.key): \(.value)"' "$metadata_file"
  fi
}

# Get current time in milliseconds
nowms() {
  # Get seconds and convert to milliseconds
  local seconds=$(date +%s)
  echo $((seconds * 1000))
}

# Set time metadata
# @param $1 key - Metadata key
# @param $2 start - Start time in milliseconds
# @param $3 end - End time in milliseconds (optional, defaults to now)
meta_time() {
  local key="$1"
  local start="$2"
  local end="${3:-$(nowms)}"
  
  # Ensure we have clean integers
  start=$(echo "$start" | sed 's/[^0-9]//g')
  end=$(echo "$end" | sed 's/[^0-9]//g')
  
  # Calculate duration in milliseconds
  local duration=$((end - start))
  
  meta_set "$key" "$duration"
}

# Create build environment
create_build_env() {
  local build_dir="$1"
  local cache_dir="$2"
  local env_dir="$3"

  # Check if directories are provided
  if [ -z "$build_dir" ] || [ -z "$cache_dir" ] || [ -z "$env_dir" ]; then
    puts_error "Missing required directory paths"
    return 1
  fi

  # Create necessary directories
  mkdir -p "$build_dir" || return 1
  mkdir -p "$cache_dir" || return 1
  mkdir -p "$env_dir" || return 1

  # Initialize metadata
  init_metadata "$cache_dir"

  # Setup initial metadata
  setup_metadata "$build_dir" "$cache_dir"

  # Export environment variables if env_dir exists
  if [ -d "$env_dir" ]; then
    export_env_dir "$env_dir"
  fi

  return 0
}
