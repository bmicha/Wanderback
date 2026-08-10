# Portage iPadOS de Wanderback — Design

**Date** : 2026-08-09
**Statut** : implémenté (build 4 sur TestFlight) ; amendé post-implémentation : orientations ITMS-90474, #if plateforme

## Objectif

Rendre Wanderback jouable nativement sur iPad, en tactile, avec la même base de code
partagée que les versions tvOS et macOS existantes. Distribution via TestFlight iOS,
avec la même procédure archive → altool que pour tvOS et macOS.

## Cadrage validé

- **iPad uniquement** (pas d'iPhone) — `TARGETED_DEVICE_FAMILY = 2`.
- **Paysage uniquement** — tous les écrans sont conçus pour un canvas 16:9 paysage (amendement : la validation App Store — ITMS-90474 — exige les 4 orientations dans l'Info.plist pour le multitâche iPad ; elles sont déclarées, et le paysage est verrouillé à l'exécution par `OrientationLockDelegate` via `@UIApplicationDelegateAdaptor`, plein écran uniquement).
- **Fenêtrage libre iPadOS 26** — pas de `UIRequiresFullScreen`, l'app est
  redimensionnable comme sur Mac.
- **iPadOS 26.0 minimum** — aligné sur tvOS 26.2 et macOS 26.0.
- **Livrable : upload TestFlight iPad.**

## Approche retenue

**Cible iOS séparée, sources partagées** (option A validée — décalque du portage
macOS) :

- Nouvelle target `WanderbackPad` dans `Wanderback.xcodeproj`, application SwiftUI
  native iOS, produit affiché « Wanderback ».
- Bundle ID : `com.bastien.Wanderback`, **identique aux cibles tvOS et macOS** —
  les trois plateformes appartiennent à la même fiche App Store Connect (c'est la
  convention déjà en place entre tvOS et macOS).
- Membership triple sur les sources Swift existantes ; aucun fichier dupliqué.
- Chaque cible garde son Info.plist, son icône et sa signature.
- Scheme partagé `WanderbackPad` commité dans `xcshareddata`.
- Les cibles tvOS et macOS et leurs procédures TestFlight ne sont pas modifiées.

Les alternatives écartées : étendre la cible tvOS en multiplateforme (mélange des
réglages, risque sur la config TestFlight tvOS) ; refondre Mac+iPad en une target
multiplateforme unique (re-validation signature/entitlements/TestFlight d'une config
fraîchement éprouvée, pour un gain limité à de la mutualisation de réglages — YAGNI).

## Composants

### 1. Réglages de la cible iPad

- `TARGETED_DEVICE_FAMILY = 2` (iPad seulement).
- `IPHONEOS_DEPLOYMENT_TARGET = 26.0`.
- Info.plist : `INFOPLIST_KEY_UISupportedInterfaceOrientations` : les 4 orientations (exigence ITMS-90474), paysage verrouillé à l'exécution — cf. amendement ci-dessus.
- Pas de `UIRequiresFullScreen` : fenêtrage iPadOS 26 accepté. Le layout s'adapte
  aux tailles variables comme il le fait déjà en fenêtre Mac (1024×640 minimum).
- `NSPhotoLibraryUsageDescription` : même texte français que le Mac (le jeu pioche
  dans la photothèque locale).
- Pas de fichier `.entitlements` a priori (pas de sandbox sur iOS ; à confirmer à
  l'archive si la signature en réclame un).

### 2. Abstractions plateforme existantes

Aucune nouvelle abstraction nécessaire. Sur iOS :

- `PlatformImage` = `UIImage` (le `#if os(macOS)` existant tombe déjà dans la
  branche UIKit).
- Les helpers `mac*` (`macFocusable`, `macFocusOnHover`, `macMoveCommand`,
  `macKeyboardShortcut`, `macCancelShortcut`, `macShortcutAction`,
  `macDefaultActionShortcut`) sont des no-op — comportement voulu : pas de gestion
  de focus clavier sur iPad, le tactile est l'interaction principale.
- `initialFocus` retombe sur `.defaultFocus` (branche non-macOS) : sans effet
  pratique sur iOS, aucun changement requis.
- `tvIgnoresSafeArea` est un no-op hors tvOS : la safe area iPad est respectée.
- `.focusSection()` (SummaryView) : exclu d'iOS via `#if !os(iOS)` (l'API n'y est pas
  disponible).
- `onExitCommand` (ContentView) : exclu d'iOS via `#if !os(iOS)` — sur iPad, le
  bouton « fermer » remplace ce raccourci système (cf. composant 4).

### 3. Échelle (`Theme.scale`)

Le design est calibré sur un canvas TV 1920×1080. Gabarits iPad en paysage :
~1376×1032 pt (13″), ~1210×834 pt (11″). Facteur d'échelle fixe **0,7** sur iOS
(`#if os(iOS)` dans `Theme`, entre le 1,0 tvOS et le 0,62 macOS). Valeur de départ
à valider à l'œil en simulateur sur les deux gabarits, ajustable après le premier
lancement visuel. Pas de refonte du design.

### 4. Interactions tactiles

- **Tap** : cartes réponse et CTA sont déjà des `Button` SwiftUI — fonctionnel
  nativement, rien à faire.
- **Retour visuel à l'appui** : les trois styles (`AnswerCardButtonStyle`,
  `GradientPillButtonStyle`, `SecondaryPillButtonStyle`) n'ont aujourd'hui aucun
  retour tactile (`isFocused` et `isHovered` restent false sur iPad). Ajout de
  `configuration.isPressed` dans le calcul `isHighlighted` de chaque style : à
  l'appui, la surbrillance existante (fond blanc / texte sombre / scale) s'applique.
  Sur tvOS et macOS, `isPressed` ne s'active qu'au moment du clic/validation —
  cumul inoffensif avec la surbrillance déjà affichée ; pas de `#if` nécessaire.
- **Quitter une partie** : bouton « fermer » discret (croix, cercle translucide
  réutilisant `Theme.answerSurface`/`answerBorder`), en haut à gauche des écrans du
  flux de jeu (GameView, RevealView, SummaryView), compilé uniquement sur iOS
  (`#if os(iOS)`). Déclenche le même chemin de sortie que `onExitCommand` (tvOS) et
  Échap (macOS). Seul élément d'UI nouveau du portage.
- **Raccourcis clavier iPad** (Magic Keyboard) : hors périmètre — les helpers
  `mac*` restent no-op sur iOS.

### 5. Icône iOS

Composite 1024×1024 régénéré depuis les 3 couches parallax (même technique que
l'icône macOS), mais **carré et sans canal alpha** : les PNG de l'icône Mac ont des
coins arrondis et de la transparence, interdits sur iOS (le système applique son
propre masque ; un canal alpha provoque le rejet ITMS-90717 à l'upload). Un jeu
`AppIcon-iOS` single-size 1024 suffit — pas de déclinaisons de tailles. Ajout dans
le même asset catalog, assigné à la cible iPad.

### 6. SwiftData / persistance

`LocationCache` fonctionne tel quel sur iOS 26. Store local à l'appareil, pas de
sync : l'iPad reconstruit son index de lieux au premier lancement. Aucun changement
de code.

## Flux de données

Inchangé : `PhotoIndexer` → `ClusteringService` → `GeocoderService` (cache
SwiftData) → `QuestionGenerator` → ViewModels → Views. Sur iPad, PhotoKit lit la
photothèque iCloud de l'appareil — mêmes données que l'Apple TV et le Mac.
`GeocoderService` utilise `MKReverseGeocodingRequest` directement (disponible dès
iOS 26 ; le chemin de compatibilité existant ne concerne que les anciens macOS).
Le portage ne touche que la couche présentation.

## Gestion d'erreurs

- Accès Photos refusé : chemin d'erreur existant (`errorMessage` dans
  `ContentView`) ; vérifier que le message guide vers
  Réglages → Confidentialité et sécurité → Photos (formulation iOS).
- Photothèque insuffisante (< 4 lieux) : `NotEnoughPlacesView` existant, inchangé.

## Tests et vérification

- **Compilation des trois cibles** sans régression (`xcodebuild` avec
  `DEVELOPER_DIR` vers Xcode-beta) : `Wanderback` (tvOS), `WanderbackMac`,
  `WanderbackPad`.
- **Vérification visuelle simulateur** : mode démo (`-demoMode` / `-screen` /
  `-noMosaic`) écran par écran sur iPad Pro 13″ et iPad 11″ — validation de
  `Theme.scale`, des zones tactiles, du retour à l'appui et du bouton « fermer ».
- **Flux réel simulateur** : photothèque du simulateur (limitée) pour le chemin
  « pas assez de lieux » ; flux complet si la photothèque du simulateur le permet.
- **TestFlight** : archive `generic/platform=iOS`, upload altool avec la clé API
  existante. Points d'attention : ajout de la plateforme iOS à la fiche App Store
  Connect existante (même bundle ID), pièges connus (SDK bêta, erreur 90513).
  Test final avec photothèque réelle sur iPad physique via TestFlight.

## Hors périmètre

- Support iPhone (aucun blocage structurel introduit, mais non livré).
- Orientation portrait.
- Raccourcis clavier iPad (Magic Keyboard).
- Refonte du design (on garde le look TV mis à l'échelle).
- Synchronisation du cache de lieux entre appareils.
- Layouts spécifiques Split View / Stage Manager au-delà de ce que le
  redimensionnement type Mac couvre déjà.
