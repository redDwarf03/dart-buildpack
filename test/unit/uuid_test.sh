#!/usr/bin/env bash

# Tests unitaires pour uuid.sh

# Charger les utilitaires de test
BP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit; pwd)
source "${BP_DIR}/test/utils/test-utils.sh"

# Charger le module à tester
source "${BP_DIR}/lib/uuid.sh"

# Test de la fonction uuid()
test_uuid() {
  echo "Test de la génération d'UUID..."
  
  # Test 1: Vérifier que uuid() génère une valeur
  local result
  result=$(uuid)
  if [ -z "$result" ]; then
    test_failure "uuid() n'a pas généré de valeur"
  fi
  test_success "uuid() génère une valeur"

  # Test 2: Vérifier le format UUID v4 (accepte majuscules et minuscules)
  if ! [[ $result =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    test_failure "Le format de l'UUID n'est pas valide: $result"
  fi
  test_success "Le format de l'UUID est valide"

  # Test 3: Vérifier que deux appels génèrent des valeurs différentes
  local result2
  result2=$(uuid)
  if [ "$result" = "$result2" ]; then
    test_failure "Deux appels à uuid() ont généré la même valeur"
  fi
  test_success "Deux appels à uuid() génèrent des valeurs différentes"
}

# Test de la fonction uuid_fallback()
test_uuid_fallback() {
  echo "Test de la fonction de fallback..."
  
  # Test 1: Vérifier que uuid_fallback() génère une valeur
  local result
  result=$(uuid_fallback)
  if [ -z "$result" ]; then
    test_failure "uuid_fallback() n'a pas généré de valeur"
  fi
  test_success "uuid_fallback() génère une valeur"

  # Test 2: Vérifier le format UUID v4 (accepte majuscules et minuscules)
  if ! [[ $result =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    test_failure "Le format de l'UUID de fallback n'est pas valide: $result"
  fi
  test_success "Le format de l'UUID de fallback est valide"

  # Test 3: Vérifier que deux appels génèrent des valeurs différentes
  local result2
  result2=$(uuid_fallback)
  if [ "$result" = "$result2" ]; then
    test_failure "Deux appels à uuid_fallback() ont généré la même valeur"
  fi
  test_success "Deux appels à uuid_fallback() génèrent des valeurs différentes"
}

# Exécuter les tests
echo "=== Tests du module uuid.sh ==="
test_uuid
test_uuid_fallback
echo "=== Tous les tests uuid.sh ont réussi ===" 