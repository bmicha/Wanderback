# Portage macOS de Wanderback — Design

**Date** : 2026-07-26
**Statut** : validé (approche), en attente de relecture de la spec

## Objectif

Rendre Wanderback jouable nativement sur macOS, avec une expérience adaptée au Mac
(fenêtre redimensionnable, souris, clavier), tout en gardant une base de code unique
partagée avec la version tvOS existante. Distribution via TestFlight macOS, avec la
même procédure archive → altool que pour tvOS.

## Approche retenue

**Cible macOS séparée, sources partagées** (option A validée) :

- Nouvelle target `Wanderback macOS` dans `Wanderback.xcodeproj`, application SwiftUI
  native (pas de Catalyst — impossible depuis tvOS de toute façon).
- Elle compile les mêmes fichiers Swift que la cible tvOS (membership double sur les
  sources existantes).
- Chaque cible garde son Info.plist, ses entitlements, son icône et sa signature.
- Les divergences de code sont gérées par `#if os(tvOS)` / `#if os(macOS)` et une
  petite couche d'abstraction plateforme.
- Cible minimale : **macOS 26.0** (alignée sur tvOS 26.2 ; `MKReverseGeocodingRequest` utilisé par GeocoderService exige macOS 26).
- La cible tvOS et sa procédure TestFlight existante ne sont pas modifiées.

## Composants

### 1. Abstraction image (`PlatformImage`)

`UIImage` n'existe pas sur macOS. On introduit dans `DesignSystem/` (ou un nouveau
dossier `Platform/`) :

```swift
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

extension Image {
    init(platformImage: PlatformImage) { ... } // Image(nsImage:) / Image(uiImage:)
}
```

Fichiers impactés :
- `Services/PhotoImageLoader.swift` — remplace `import UIKit` et les signatures
  `UIImage` par `PlatformImage`. Note : sur macOS, `PHCachingImageManager.requestImage`
  renvoie déjà un `NSImage`, l'API PhotoKit est identique.
- `Views/GameView.swift`, `Views/HomeView.swift`, `Views/RevealView.swift` —
  `@State` typés `PlatformImage` et `Image(platformImage:)` à la place de
  `Image(uiImage:)`.

### 2. Isolation des APIs tvOS

- `.focusSection()` (`SummaryView`, `RevealView`) : indisponible sur macOS → extension
  `View.tvFocusSection()` qui ne fait rien hors tvOS (évite de parsemer les vues de
  `#if`).
- `.onExitCommand` (`ContentView.gameFlow`) : disponible sur macOS (10.15+) où il
  correspond à la touche Échap → **conservé tel quel** : Échap quitte la partie,
  comme le bouton Menu de la télécommande.
- Focus tvOS (cartes réponse) : sur Mac, le focus clavier SwiftUI natif (Tab/flèches)
  reste utilisable mais l'interaction principale est la souris.

### 3. Adaptations Mac de l'UI

- **Fenêtre** : `WindowGroup` avec taille par défaut 1280×720 et minimale 1024×640
  (`.defaultSize` / `.frame(minWidth:minHeight:)`), plein écran macOS natif possible.
  Titre de fenêtre « Wanderback ».
- **Échelle** : le design est calibré sur un canvas 1920×1080 regardé à 3 m ; en
  fenêtre Mac les tailles fixes (ex. `font(.system(size: 28))`, paddings de 200 pt)
  sont massives. On introduit dans `Theme` un facteur d'échelle plateforme
  (`Theme.scale`, ≈ 0.6 sur macOS, 1.0 sur tvOS) appliqué aux tokens de taille les
  plus visibles (typo, paddings, rayons). Ajustement pragmatique, pas de refonte.
- **Souris** : effet de survol sur les 4 cartes réponse et les boutons
  (`.onHover` / `.hoverEffect` maison : légère élévation + bordure, réutilisant le
  style focus tvOS existant).
- **Clavier** : touches `1`–`4` pour répondre, `Entrée` pour « continuer / round
  suivant », `Échap` pour quitter la partie.

### 4. Icône macOS

Aplatir les 3 couches parallax existantes (back/middle/front des `.imagestack`) en une
icône macOS classique (`AppIcon` macOS dans le même asset catalog, jeux de tailles
16→1024 générés depuis le composite 1024×1024).

### 5. Permissions et entitlements

Nouveau `WanderbackMac.entitlements` :
- `com.apple.security.app-sandbox` = true (requis pour App Store/TestFlight)
- `com.apple.security.personal-information.photos-library` = true

Info.plist macOS : `NSPhotoLibraryUsageDescription` (texte français expliquant que le
jeu pioche dans la photothèque locale). L'entitlement tvOS `user-management` ne
s'applique pas au Mac.

PhotoKit lit la photothèque système du Mac (iCloud Photos) — même API, mêmes données
que sur l'Apple TV.

### 6. SwiftData / persistance

`LocationCache` fonctionne tel quel sur macOS 26+. Le store est propre à chaque
appareil (pas de sync), comme aujourd'hui : le Mac reconstruira son index de lieux au
premier lancement. Aucun changement de code attendu.

## Flux de données

Inchangé : `PhotoIndexer` → `ClusteringService` → `GeocoderService` (cache SwiftData)
→ `QuestionGenerator` → ViewModels → Views. Le portage ne touche que la couche
présentation et le chargement d'images.

## Gestion d'erreurs

- Accès Photos refusé sur Mac : le chemin d'erreur existant (`errorMessage` dans
  `ContentView`) s'applique ; vérifier que le message guide vers
  Réglages Système → Confidentialité → Photos.
- Photothèque insuffisante (< 4 lieux) : `NotEnoughPlacesView` existant, inchangé.

## Tests et vérification

- Compilation des deux cibles (`xcodebuild -scheme Wanderback` tvOS +
  `xcodebuild -scheme "Wanderback macOS"`) sans régression tvOS.
- Lancement local sur ce Mac : flux complet (indexation → accueil → partie Souvenir
  et Challenge → révélation → résumé) avec la photothèque réelle.
- Mode démo (`-demoMode` / `-screen`) pour vérifier visuellement chaque écran en
  fenêtre 1280×720 et en plein écran.
- Vérification clavier (1–4, Entrée, Échap) et survol souris.
- Archive macOS + upload TestFlight (procédure existante adaptée : destination
  `generic/platform=macOS`).

## Hors périmètre

- Refonte du design pour Mac (on garde le look TV, juste mis à l'échelle).
- Synchronisation du cache de lieux entre appareils.
- Version iOS/iPadOS.
- Menu bar macOS personnalisé, Touch Bar, etc.
