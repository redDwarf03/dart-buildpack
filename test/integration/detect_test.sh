#!/usr/bin/env bash

# Tests d'intégration pour le script detect

# Charger les utilitaires de test
BP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit; pwd)
source "${BP_DIR}/test/utils/test-utils.sh"

# Test de détection d'une application Dart
test_detect_dart_app() {
  echo "Test de détection d'une application Dart..."
  
  # Utiliser le fixture dart-app
  local app_dir="${BP_DIR}/test/fixtures/dart-app"
  
  # Exécuter la détection
  local detect_output
  detect_output=$("$BP_DIR/bin/detect" "$app_dir")
  local detect_status=$?
  
  # Vérifier le statut de sortie
  assert_equals 0 "$detect_status" "La détection devrait réussir"
  
  # Vérifier la sortie
  assert_equals "Dart" "$detect_output" "La sortie devrait être 'Dart'"
  
  test_success "Application Dart détectée correctement"
}

# Test de détection d'une application Flutter
test_detect_flutter_app() {
  echo "Test de détection d'une application Flutter..."
  
  # Utiliser le fixture flutter-app
  local app_dir="${BP_DIR}/test/fixtures/flutter-app"
  
  # Exécuter la détection
  local detect_output
  detect_output=$("$BP_DIR/bin/detect" "$app_dir")
  local detect_status=$?
  
  # Vérifier le statut de sortie
  assert_equals 0 "$detect_status" "La détection devrait réussir"
  
  # Vérifier la sortie
  assert_equals "Flutter" "$detect_output" "La sortie devrait être 'Flutter'"
  
  test_success "Application Flutter détectée correctement"
}

# Test de détection avec un projet non-Dart
test_detect_non_dart_app() {
  echo "Test de détection d'une application non-Dart..."
  
  # Utiliser le fixture not-dart-app
  local app_dir="${BP_DIR}/test/fixtures/not-dart-app"
  
  # Exécuter la détection
  "$BP_DIR/bin/detect" "$app_dir" > /dev/null 2>&1
  local detect_status=$?
  
  # Vérifier que la détection échoue
  assert_equals 1 "$detect_status" "La détection devrait échouer"
  
  test_success "Application non-Dart rejetée correctement"
}

# Test de détection avec un pubspec.yaml invalide
test_detect_invalid_pubspec() {
  echo "Test de détection avec un pubspec.yaml invalide..."
  
  # Utiliser le fixture invalid-dart-app
  local app_dir="${BP_DIR}/test/fixtures/invalid-dart-app"
  
  # Exécuter la détection
  "$BP_DIR/bin/detect" "$app_dir" > /dev/null 2>&1
  local detect_status=$?
  
  # Vérifier que la détection échoue
  assert_equals 1 "$detect_status" "La détection devrait échouer"
  
  test_success "pubspec.yaml invalide rejeté correctement"
}

# Exécuter les tests
echo "=== Tests d'intégration du script detect ==="
test_detect_dart_app
test_detect_flutter_app
test_detect_non_dart_app
test_detect_invalid_pubspec
echo "=== Tous les tests d'intégration detect ont réussi ===" 