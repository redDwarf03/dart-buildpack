# Dart Buildpack

Ce buildpack est conçu pour déployer des applications Dart sur Scalingo. Il gère l'installation de Dart, la gestion des dépendances, la compilation et le déploiement de votre application.

## Fonctionnalités

- Installation automatique de Dart SDK
- Gestion des dépendances avec `pub`
- Support des builds web et natifs
- Gestion du cache pour les dépendances
- Configuration d'environnement flexible
- Support des métadonnées de build
- Système de fonctionnalités extensible
- Gestion des erreurs et des avertissements

## Structure du Buildpack

```
.
├── bin/
│   ├── compile    # Script principal de compilation
│   ├── detect     # Détection de l'application Dart
│   └── release    # Configuration du déploiement
├── lib/
│   ├── binaries.sh    # Gestion de l'installation de Dart
│   ├── builddata.sh   # Collecte des données de build
│   ├── cache.sh       # Gestion du cache
│   ├── dependencies.sh # Gestion des dépendances
│   ├── environment.sh  # Configuration de l'environnement
│   ├── failure.sh     # Gestion des erreurs
│   ├── features.sh    # Système de fonctionnalités
│   ├── json.sh        # Manipulation JSON/YAML
│   ├── kvstore.sh     # Stockage clé-valeur
│   ├── metadata.sh    # Gestion des métadonnées
│   └── vendor/        # Dépendances externes
└── test/             # Tests du buildpack
```

## Configuration

### Variables d'environnement

- `DART_SDK`: Chemin vers le SDK Dart
- `PUB_CACHE`: Emplacement du cache des packages
- `DART_ENV`: Environnement de déploiement (production/development)
- `DART_BUILD_FLAGS`: Flags de compilation supplémentaires
- `DART_VERBOSE`: Mode verbeux pour le build
- `DART_PACKAGES_CACHE`: Activation/désactivation du cache des packages

### Configuration du projet

Le buildpack détecte automatiquement les applications Dart en cherchant un fichier `pubspec.yaml` à la racine du projet. Ce fichier doit contenir :

```yaml
name: mon_application
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  # Dépendances de l'application
```

## Processus de Build

1. **Détection** : Vérifie la présence de `pubspec.yaml`
2. **Installation** : Installe la version de Dart spécifiée
3. **Dépendances** : Installe les dépendances avec `pub get`
4. **Compilation** : Compile l'application selon le type (web/natif)
5. **Cache** : Sauvegarde le cache des dépendances
6. **Métadonnées** : Enregistre les informations de build

## Fonctionnalités Avancées

### Gestion des Dépendances

Le buildpack supporte :
- Installation des dépendances depuis pub.dev
- Gestion des versions avec contraintes sémantiques
- Cache des packages pour des builds plus rapides
- Support des dépendances privées

### Compilation

Support pour différents types de compilation :
- Web (JavaScript)
- Natif (exécutable)
- AOT (Ahead-of-Time)
- JIT (Just-in-Time)

### Cache

Le système de cache gère :
- Les packages installés
- Les artefacts de compilation
- Les métadonnées de build
- Les configurations d'environnement

### Métadonnées

Stockage d'informations sur :
- Version de Dart utilisée
- Temps de build
- Statut de la compilation
- Erreurs et avertissements
- Métriques de performance

## Gestion des Erreurs

Le buildpack détecte et gère plusieurs types d'erreurs :
- Erreurs de compilation
- Problèmes de dépendances
- Conflits de versions
- Problèmes de configuration
- Erreurs d'environnement

## Tests

Le buildpack inclut un système de tests complet qui vérifie :
- La détection des applications Dart
- L'installation de Dart
- La gestion des dépendances
- Le système de cache
- La compilation
- La gestion des métadonnées
- Les fonctionnalités

## Utilisation

1. Configurez votre application avec un `pubspec.yaml`
2. Déployez sur Scalingo
3. Le buildpack détectera automatiquement votre application Dart
4. Le processus de build s'exécutera automatiquement

## Exemples

### Application Web

```yaml
name: mon_application_web
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  shelf: ^1.4.0
```

### Application Native

```yaml
name: mon_application_native
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  args: ^2.4.0
```

## Support

Pour plus d'informations et d'aide :
- [Documentation Dart](https://dart.dev/guides)
- [Documentation Scalingo](https://doc.scalingo.com)
- [Issues GitHub](https://github.com/Scalingo/dart-buildpack/issues)

## Licence

Ce buildpack est distribué sous licence MIT. Voir le fichier LICENSE pour plus de détails.
