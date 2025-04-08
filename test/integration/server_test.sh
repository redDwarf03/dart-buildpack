#!/usr/bin/env bash

# Tests d'intégration pour l'application serveur Dart

# Charger les utilitaires de test
BP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit; pwd)
echo "BP_DIR: $BP_DIR"
echo "Compile script: $BP_DIR/bin/compile"
echo "Dependencies:"
ls -la "$BP_DIR/lib/"

source "${BP_DIR}/test/utils/test-utils.sh"
source "${BP_DIR}/lib/dart.sh"

# Installer Dart si nécessaire
install_dart_for_tests() {
  if ! check_dart_installed; then
    echo "Installation de Dart..."
    curl -fsSL https://dl.google.com/dart/archive/latest/sdk/dartsdk-macos-x64-release.zip -o dart.zip
    unzip -q dart.zip
    export PATH="$PWD/dart-sdk/bin:$PATH"
    rm dart.zip
  fi
  echo "Version de Dart installée : $(dart --version)"
}

# Test de détection de l'application serveur
test_detect_server_app() {
  echo "Test de détection de l'application serveur Dart..."
  
  # Utiliser le fixture dart-server-app
  local app_dir="${BP_DIR}/test/fixtures/dart-server-app"
  
  # Exécuter la détection
  local detect_output
  detect_output=$("$BP_DIR/bin/detect" "$app_dir")
  local detect_status=$?
  
  # Vérifier le statut de sortie
  assert_equals 0 "$detect_status" "La détection devrait réussir"
  
  # Vérifier la sortie
  assert_equals "Dart" "$detect_output" "La sortie devrait être 'Dart'"
  
  test_success "Application serveur Dart détectée correctement"
}

# Test de compilation de l'application serveur
test_compile_server_app() {
  echo "Test de compilation de l'application serveur Dart..."
  
  # Utiliser le fixture dart-server-app
  local app_dir="${BP_DIR}/test/fixtures/dart-server-app"
  local cache_dir="${BP_DIR}/test/cache"
  local env_dir="${BP_DIR}/test/env"
  
  # Créer les répertoires nécessaires
  mkdir -p "$cache_dir"
  mkdir -p "$env_dir"
  
  # Installer Dart si nécessaire
  install_dart_for_tests
  
  echo "Compilation de l'application..."
  echo "Répertoire de l'application : $app_dir"
  echo "Répertoire de cache : $cache_dir"
  echo "Répertoire d'environnement : $env_dir"
  
  # Exécuter la compilation avec les logs
  "$BP_DIR/bin/compile" "$app_dir" "$cache_dir" "$env_dir"
  local compile_status=$?
  
  echo "Statut de compilation : $compile_status"
  
  # Vérifier le statut de sortie
  assert_equals 0 "$compile_status" "La compilation devrait réussir"
  
  # Vérifier que le binaire a été créé
  assert_file_exists "${app_dir}/bin/server" "Le binaire server devrait exister"
  
  test_success "Application serveur Dart compilée correctement"
}

# Exécuter les tests
echo "=== Tests d'intégration de l'application serveur ==="
test_detect_server_app
test_compile_server_app
echo "=== Tous les tests d'intégration de l'application serveur ont réussi ===" 