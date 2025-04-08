#!/usr/bin/env bash

# Fonctions utilitaires pour les tests du buildpack

# Couleurs pour une meilleure lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Répertoire du buildpack
BP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit; pwd)

# @description Affiche un message de test réussi
# @param $1 Message de succès
test_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

# @description Affiche un message de test échoué et quitte
# @param $1 Message d'erreur
test_failure() {
  echo -e "${RED}✗ $1${NC}"
  exit 1
}

# @description Crée un environnement de test temporaire
# @return Le chemin du répertoire temporaire
create_temp_env() {
  local temp_dir
  temp_dir=$(mktemp -d)
  echo "$temp_dir"
}

# @description Nettoie l'environnement de test
# @param $1 Chemin du répertoire temporaire
cleanup_temp_env() {
  rm -rf "$1"
}

# @description Crée un projet Dart de test
# @param $1 Chemin du répertoire du projet
create_test_app() {
  local app_dir="$1"
  mkdir -p "$app_dir/bin"
  
  # Créer un pubspec.yaml minimal
  cat > "$app_dir/pubspec.yaml" << EOF
name: test_app
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  shelf: ^1.4.0
EOF

  # Créer un fichier Dart minimal
  cat > "$app_dir/bin/server.dart" << EOF
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  var handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(_echoRequest);

  var server = await io.serve(handler, 'localhost', 8080);
  print('Serving at http://\${server.address.host}:\${server.port}');
}

shelf.Response _echoRequest(shelf.Request request) =>
    shelf.Response.ok('Hello, Dart!');
EOF
}

# @description Vérifie si une commande existe
# @param $1 Nom de la commande
assert_command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    test_failure "Commande '$1' non trouvée"
  fi
}

# @description Vérifie si un fichier existe
# @param $1 Chemin du fichier
assert_file_exists() {
  if [ ! -f "$1" ]; then
    test_failure "Fichier '$1' non trouvé"
  fi
}

# @description Vérifie si un répertoire existe
# @param $1 Chemin du répertoire
assert_dir_exists() {
  if [ ! -d "$1" ]; then
    test_failure "Répertoire '$1' non trouvé"
  fi
}

# @description Vérifie si une chaîne est présente dans un fichier
# @param $1 Chaîne à rechercher
# @param $2 Chemin du fichier
assert_contains() {
  if ! grep -q "$1" "$2"; then
    test_failure "La chaîne '$1' n'a pas été trouvée dans '$2'"
  fi
}

# @description Vérifie si deux valeurs sont égales
# @param $1 Valeur attendue
# @param $2 Valeur réelle
assert_equals() {
  if [ "$1" != "$2" ]; then
    test_failure "Attendu '$1' mais obtenu '$2'"
  fi
}

# @description Vérifie si une valeur est vraie
# @param $1 Valeur à tester
assert_true() {
  if [ "$1" != "true" ] && [ "$1" != "0" ]; then
    test_failure "La valeur devrait être vraie"
  fi
}

# @description Vérifie si une valeur est fausse
# @param $1 Valeur à tester
assert_false() {
  if [ "$1" = "true" ] || [ "$1" = "0" ]; then
    test_failure "La valeur devrait être fausse"
  fi
} 