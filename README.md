# 🗺️ Wanderback

> Jeu de reconnaissance de lieux à partir de tes photos de vacances · Apple TV (tvOS)

Wanderback est une application tvOS qui pioche dans ta bibliothèque iCloud pour te faire deviner où ont été prises tes propres photos de voyage. Inspiré de GeoGuessr, mais avec tes souvenirs personnels.

## Concept

- La photo d'un de tes voyages s'affiche en plein écran sur la TV
- Tu choisis parmi 4 lieux proposés (issus de ta propre bibliothèque)
- Deux modes : **Souvenir** (ambiance nostalgie, révélation cinématique) et **Challenge** (chrono + score)
- 100% local — aucune donnée ne quitte l'appareil

## Prérequis

- Apple TV 4K (2e ou 3e génération)
- tvOS 17.0+
- Bibliothèque iCloud avec au moins **4 destinations distinctes** avec GPS activé

## Documentation

| Fichier | Contenu |
|---|---|
| [`docs/specs.md`](docs/specs.md) | Spécifications produit complètes (vision, modes, flux, architecture) |
| [`docs/technique-et-setup.md`](docs/technique-et-setup.md) | UX TV, états de chargement, setup Xcode, GitHub, outils |
| [`docs/wireframes.html`](docs/wireframes.html) | Maquettes interactives des 6 écrans principaux (ouvrir dans un navigateur) |

## Stack technique

- **Swift 5.9+** / **SwiftUI**
- **PhotoKit** — accès bibliothèque iCloud
- **CoreLocation / CLGeocoder** — géocodage inverse (GPS → nom de ville)
- **MapKit** — carte animée sur l'écran de révélation
- **SwiftData** — cache local (index des lieux géocodés)

## Structure du projet

```
wanderback/
├── Wanderback.xcodeproj/
├── Wanderback/
│   ├── App/                    # Point d'entrée
│   ├── Models/                 # PhotoLocation, LocationCluster, GameRound...
│   ├── ViewModels/             # PhotoLibraryViewModel, GameViewModel...
│   ├── Views/                  # HomeView, GameView, RevealView...
│   ├── Services/               # PhotoIndexer, GeocoderService, QuestionGenerator
│   └── Persistence/            # LocationCache (SwiftData)
├── WanderbackTests/
├── WanderbackUITests/
└── docs/
```

## Démarrage

Voir [`docs/technique-et-setup.md`](docs/technique-et-setup.md) — section **4. Démarrage du Projet Xcode**.

## Roadmap

- **V1 — MVP** : indexation GPS, génération de questions, mode Challenge, écran de révélation
- **V2 — Enrichissement** : mode Souvenir cinématique, sélection par voyage/année
- **V3 — Social** : multijoueur local, Game Center, SharePlay
