# Wanderback — Spécifications de l'application Apple TV

> Application tvOS — Jeu de reconnaissance de lieux à partir des photos personnelles iCloud

---

## 1. Vision & Concept

**Wanderback** est un jeu de reconnaissance de lieux pour Apple TV qui utilise les propres photos de vacances de l'utilisateur. Inspiré de GeoGuessr, il propose une expérience intimement personnelle : on affiche une photo prise par l'utilisateur, et il doit deviner où elle a été prise en choisissant parmi 4 lieux proposés.

L'originalité du concept réside dans le fait que le joueur connaît (ou croit connaître) les lieux — ce sont ses propres souvenirs. Le jeu crée naturellement des moments de partage en famille devant la TV : "Ah oui, c'était à Séville !", "Non non, c'est Porto j'en suis sûr !".

**Proposition de valeur principale :**
- Zéro contenu à configurer — le jeu se génère automatiquement depuis la bibliothèque iCloud
- Accessible à toute la famille, aucune connaissance géographique requise
- Double dimension : jeu + voyage nostalgique dans les souvenirs

---

## 2. Modes de jeu

Au lancement d'une partie, le joueur choisit entre deux modes.

### 2.1 Mode Souvenir 🏡

Ambiance détendue, sans pression de temps. L'objectif est de revivre des moments ensemble.

- Pas de chronomètre
- Pas de score affiché pendant la partie
- Après chaque photo, **révélation cinématique** du lieu :
  - Zoom animé sur la carte (MapKit) vers le lieu exact
  - Affichage de la date de la photo
  - Distance depuis le domicile (si configuré)
  - Diaporama discret d'autres photos prises le même jour en arrière-plan
  - Nom du lieu (ville + pays) affiché en grand
- En fin de partie : récapitulatif des voyages parcourus

### 2.2 Mode Challenge ⏱️

Version compétitive pour pimenter la soirée.

- Chronomètre par round (30 secondes par défaut, configurable)
- Système de score :
  - Bonne réponse rapide = score maximum (ex: 1000 pts)
  - Plus la réponse est tardive, moins de points
  - Mauvaise réponse = 0 pts
- Affichage du score en temps réel
- Classement en fin de partie (utile pour jouer à plusieurs en local, chacun son tour)
- La révélation cinématique est plus rapide (5 secondes max)

---

## 3. Flux Utilisateur

### 3.1 Premier lancement

```
Écran d'accueil
  → Demande d'autorisation d'accès à la photothèque
      → Accordée → Analyse silencieuse des photos en arrière-plan
      → Refusée → Écran d'explication avec lien vers Réglages
```

L'analyse initiale indexe toutes les photos disposant de coordonnées GPS et les regroupe par lieu géographique. Cette opération se fait une seule fois, puis est mise en cache.

### 3.2 Lancement d'une partie

```
Écran principal
  → Choix du mode : [Souvenir] ou [Challenge]
  → Choix du voyage (optionnel) :
      - "Toutes mes photos" (par défaut)
      - Sélection d'une année ou d'un voyage spécifique
  → Nombre de rounds : 5 / 10 / 20
  → Lancement de la partie
```

### 3.3 Round de jeu

```
Affichage de la photo (plein écran, sans indices de lieu)
  → 4 options proposées sous la photo
  → Le joueur sélectionne avec la télécommande Siri Remote
  → Validation
  → Écran de révélation (court en Challenge, cinématique en Souvenir)
  → Round suivant
```

### 3.4 Fin de partie

```
Écran récapitulatif :
  - Carte du monde avec tous les lieux de la partie marqués
  - Score final (mode Challenge)
  - Distance totale parcourue en km
  - Option : "Rejouer", "Changer de mode", "Quitter"
```

---

## 4. Génération des Questions

### 4.1 Sélection de la photo

**Règle fondamentale : toute photo sans coordonnées GPS est exclue du jeu.** C'est un filtre strict appliqué dès l'indexation — ces photos n'entrent jamais dans le pool de questions.

Une photo est éligible si elle répond à **tous** les critères suivants :
- ✅ `asset.location != nil` — possède des coordonnées GPS (critère obligatoire)
- ✅ Le géocodage inverse a retourné une ville identifiable
- ✅ N'est pas un screenshot (filtrer via `PHAssetMediaSubtype.photoScreenshot`)
- ✅ Résolution suffisante pour un affichage TV (> 1 MP recommandé)
- ⬜ N'est pas une photo de document/texte (optionnel, via Vision framework — V2)

Photos typiquement **sans GPS** (à ignorer silencieusement) :
- Photos reçues par iMessage/WhatsApp (métadonnées GPS supprimées à l'envoi)
- Screenshots
- Photos scannées ou importées depuis un ordinateur
- Photos prises avec l'app Appareil en mode avion sans Wi-Fi de triangulation
- Images téléchargées depuis Internet

### 4.2 Génération des mauvaises réponses (distracteurs)

Les 3 mauvaises réponses doivent être :
- **Issues de la bibliothèque de l'utilisateur** → lieux que l'utilisateur a réellement visités → plus difficile et plus amusant
- **Géographiquement distinctes** entre elles et par rapport à la bonne réponse (ex: pas deux villes de la même région)
- **Au même niveau de granularité** que la bonne réponse (si la réponse est "Paris, France", les distracteurs sont aussi des villes, pas des pays)

Algorithme suggéré :
1. Récupérer tous les clusters de lieux distincts de la bibliothèque
2. Exclure le cluster de la bonne réponse
3. Sélectionner 3 clusters au hasard avec une contrainte de distance minimale entre eux (ex: > 200 km)
4. Afficher les 4 options dans un ordre aléatoire

---

## 5. Spécifications Techniques

### 5.1 Plateforme & Prérequis

| Élément | Valeur |
|---|---|
| Plateforme | Apple TV (tvOS) |
| Version minimale tvOS | tvOS 17.0 |
| Langage | Swift 5.9+ |
| UI Framework | SwiftUI |
| Xcode minimum | Xcode 15 |
| Pas de backend requis | L'app est 100% locale |

> ℹ️ tvOS 17 est la version courante sur Apple TV 4K (3e génération). Cibler tvOS 17+ permet d'utiliser les dernières APIs SwiftUI sans compromis.

### 5.2 Frameworks Apple utilisés

#### PhotoKit (`import Photos`)
Principal framework d'accès à la bibliothèque photos.

```swift
// Exemple : récupérer les photos avec localisation
let options = PHFetchOptions()
options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
let assets = PHAsset.fetchAssets(with: options)

// Accéder aux coordonnées GPS d'une photo
let location: CLLocation? = asset.location
```

Points clés :
- `PHAsset.location` → coordonnées GPS directement disponibles (pas besoin de lire les EXIF manuellement)
- `PHCachingImageManager` → chargement performant des images pour la TV (haute résolution)
- Accès iCloud transparent : PhotoKit télécharge automatiquement les photos iCloud si nécessaire

#### CoreLocation (`import CoreLocation`)
Pour le géocodage inverse (coordonnées GPS → nom de lieu lisible).

```swift
let geocoder = CLGeocoder()
geocoder.reverseGeocodeLocation(location) { placemarks, error in
    if let placemark = placemarks?.first {
        let city = placemark.locality        // "Paris"
        let country = placemark.country      // "France"
        let countryCode = placemark.isoCountryCode  // "FR"
    }
}
```

> ⚠️ Le géocodage inverse est limité à ~50 requêtes/min par Apple. Il faut mettre les résultats en cache (base de données locale) pour ne pas re-géocoder les mêmes coordonnées à chaque lancement.

#### MapKit (`import MapKit`)
Pour l'écran de révélation — affichage de la carte avec le lieu exact.

```swift
// SwiftUI — Carte centrée sur un lieu
Map(position: $cameraPosition) {
    Marker("Lieu de la photo", coordinate: photoCoordinate)
}
```

tvOS supporte MapKit mais avec des interactions limitées (pas de zoom tactile). La carte sera animée programmatiquement pour l'effet de "zoom cinématique".

#### Vision Framework (`import Vision`) — optionnel
Pour filtrer les screenshots et photos de documents afin de ne proposer que de vraies photos de voyage.

### 5.3 Architecture de l'application (MVVM)

```
Wanderback/
├── App/
│   └── WanderbackApp.swift          # Point d'entrée
├── Models/
│   ├── PhotoLocation.swift           # Photo + ses coordonnées + lieu géocodé
│   ├── LocationCluster.swift         # Regroupement de photos par lieu
│   ├── GameSession.swift             # État d'une partie en cours
│   └── GameRound.swift               # Une question (photo + 4 options)
├── ViewModels/
│   ├── PhotoLibraryViewModel.swift   # Accès PhotoKit, indexation
│   ├── GameViewModel.swift           # Logique de jeu (rounds, score, timer)
│   └── RevealViewModel.swift         # Animation de révélation
├── Views/
│   ├── HomeView.swift                # Écran d'accueil + choix de mode
│   ├── GameView.swift                # Écran principal du jeu
│   ├── AnswerOptionsView.swift       # Les 4 boutons de réponse
│   ├── RevealView.swift              # Écran de révélation du lieu
│   └── SummaryView.swift             # Récapitulatif de fin de partie
├── Services/
│   ├── PhotoIndexer.swift            # Indexation et clustering des photos
│   ├── GeocoderService.swift         # Géocodage inverse avec cache
│   └── QuestionGenerator.swift      # Génération des questions + distracteurs
└── Persistence/
    └── LocationCache.swift           # Cache local (SwiftData ou UserDefaults)
```

### 5.4 Modèle de données

```swift
// Une photo avec sa localisation géocodée
struct PhotoLocation {
    let assetIdentifier: String   // ID unique PhotoKit
    let coordinate: CLLocationCoordinate2D
    let date: Date
    let cityName: String          // "Lisbonne"
    let countryName: String       // "Portugal"
    let countryCode: String       // "PT"
}

// Un cluster géographique (regroupement de photos d'un même lieu)
struct LocationCluster {
    let id: UUID
    let name: String              // "Lisbonne, Portugal"
    let centerCoordinate: CLLocationCoordinate2D
    let photos: [PhotoLocation]
    let radiusKm: Double          // Rayon du cluster
}

// Un round de jeu
struct GameRound {
    let photo: PhotoLocation
    let correctCluster: LocationCluster
    let wrongOptions: [LocationCluster]  // Exactement 3
    var shuffledOptions: [LocationCluster]  // correct + 3 wrong mélangés
    var selectedOption: LocationCluster?
    var isCorrect: Bool { selectedOption?.id == correctCluster.id }
    var score: Int  // Calculé selon le temps de réponse (mode Challenge)
}
```

### 5.5 Stratégie de clustering géographique

Pour regrouper les photos par lieu, on utilise un algorithme de clustering basé sur la distance :

- Deux photos appartiennent au même cluster si elles sont à moins de **X km** l'une de l'autre
- Valeur recommandée : **5 km** pour les villes, adaptable selon le zoom souhaité
- Algorithme suggéré : **DBSCAN** (simple à implémenter en Swift) ou clustering hiérarchique
- Le nom du cluster est déterminé par géocodage inverse du centroïde

### 5.6 Cache et Performance

| Opération | Stratégie |
|---|---|
| Index des photos GPS | Calculé au 1er lancement, mis à jour en delta lors des lancements suivants |
| Géocodage inverse | Stocké en local (SwiftData) — une entrée par coordonnée unique |
| Miniatures photos | `PHCachingImageManager.startCachingImages()` avant chaque round |
| Photos haute résolution | Chargées à la demande lors de l'affichage plein écran |

Stockage recommandé : **SwiftData** (introduit iOS/tvOS 17) pour le cache de géocodage et l'index des clusters.

### 5.7 Gestion des permissions

tvOS requiert une déclaration dans `Info.plist` :

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Wanderback utilise vos photos pour créer des questions de jeu personnalisées basées sur vos voyages.</string>
```

Sur tvOS, la demande d'autorisation est gérée via :
```swift
PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
    // .authorized, .limited, .denied, .restricted
}
```

> ℹ️ En mode "accès limité" (.limited), l'utilisateur choisit quelles photos partager — le jeu fonctionnera mais avec un catalogue réduit.

---

## 6. Expérience Télécommande (Siri Remote)

La télécommande Apple TV est le seul périphérique d'interaction. Design des contrôles :

| Action | Geste Siri Remote |
|---|---|
| Naviguer entre les 4 options | Swipe gauche/droite ou D-pad |
| Valider une réponse | Clic (bouton central) |
| Mettre en pause / reprendre | Bouton Play/Pause |
| Retour au menu | Bouton Menu / bouton Retour |

Les éléments focusables doivent utiliser le système de focus tvOS natif (`.focusable()` en SwiftUI) pour bénéficier de l'animation de mise en évidence automatique.

---

## 7. Écrans Principaux (wireframe textuel)

### Écran de jeu (GameView)

```
┌─────────────────────────────────────────────────────┐
│  [LOGO]                          Round 3/10  [SCORE] │
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │                                                 │ │
│  │              PHOTO PLEIN FORMAT                 │ │
│  │              (sans indices de lieu)             │ │
│  │                                                 │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│  ┌──────────────┐  ┌──────────────┐                  │
│  │  🇫🇷 Paris   │  │  🇵🇹 Lisbonne │                  │
│  │   France     │  │   Portugal   │                  │
│  └──────────────┘  └──────────────┘                  │
│  ┌──────────────┐  ┌──────────────┐                  │
│  │  🇪🇸 Séville │  │  🇮🇹 Rome    │                  │
│  │   Espagne    │  │   Italie     │                  │
│  └──────────────┘  └──────────────┘                  │
└─────────────────────────────────────────────────────┘
```

### Écran de révélation (RevealView)

```
┌─────────────────────────────────────────────────────┐
│                                                       │
│   ✅ Bonne réponse !  (ou ❌ C'était...)              │
│                                                       │
│   📍 LISBONNE, PORTUGAL                               │
│   📅 14 juillet 2022 · 📏 1 847 km de chez vous      │
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │                                                 │ │
│  │         CARTE ANIMÉE — ZOOM SUR LISBONNE        │ │
│  │              📍 Marqueur sur le lieu             │ │
│  │                                                 │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│   [Autres photos ce jour-là : 🖼️ 🖼️ 🖼️ 🖼️]           │
│                                                       │
│                  [ Round suivant → ]                  │
└─────────────────────────────────────────────────────┘
```

---

## 8. Défis Techniques & Points d'Attention

### 8.1 Photos sans GPS — Filtre strict à l'indexation

C'est le cas le plus fréquent et le plus important à gérer. **Les photos sans GPS sont ignorées dès la phase d'indexation** — elles ne sont jamais stockées en cache ni proposées comme questions.

Implémentation dans `PhotoIndexer` :

```swift
func fetchEligibleAssets() -> [PHAsset] {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(
        format: "mediaType == %d AND NOT (mediaSubtype & %d) != 0",
        PHAssetMediaType.image.rawValue,
        PHAssetMediaSubtype.photoScreenshot.rawValue
    )
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

    let allAssets = PHAsset.fetchAssets(with: options)
    var eligible: [PHAsset] = []

    allAssets.enumerateObjects { asset, _, _ in
        // Filtre GPS — règle fondamentale
        if asset.location != nil {
            eligible.append(asset)
        }
        // Les photos sans location sont silencieusement ignorées
    }
    return eligible
}
```

**Ce que l'UI doit montrer** (écran d'accueil) :
```
📸 1 247 photos dans ta bibliothèque
📍 342 photos avec localisation GPS  ← seules celles-ci sont jouables
🗺️ 23 lieux · 8 pays
```

**Cas limite — moins de 4 lieux GPS distincts** :
Si la bibliothèque indexée contient moins de 4 clusters de lieux distincts, il est impossible de générer une question valide (1 bonne réponse + 3 distracteurs). Afficher :
```
[📍]
Pas assez de destinations trouvées

Wanderback a trouvé seulement 2 lieux dans tes photos.
Il en faut au moins 4 différents pour jouer.

💡 Active "Localisation" sur ton iPhone pour tes prochaines
   photos, et reviens après ton prochain voyage !

[ Voir comment faire ]    [ Mode démo ]
```

Le **Mode démo** peut proposer un jeu de photos d'exemple fourni avec l'app, pour permettre de découvrir l'expérience même sans bibliothèque GPS suffisante.

### 8.2 Bibliothèque trop petite
Si l'utilisateur a moins de 4 lieux distincts dans sa bibliothèque, il est impossible de générer 4 options différentes. Gérer ce cas avec un message d'erreur approprié.

### 8.3 Téléchargement iCloud
Les photos stockées sur iCloud et non téléchargées localement nécessitent une connexion internet. PhotoKit gère cela mais il faut prévoir un indicateur de chargement.

### 8.4 Confidentialité
Toutes les données restent sur l'appareil. Aucune photo ni coordonnée GPS n'est envoyée à un serveur externe. C'est un argument de vente important à mettre en avant.

### 8.5 Clusters trop concentrés géographiquement
Un utilisateur qui a beaucoup de photos dans la même ville (ex: sa ville natale) peut avoir des clusters très proches qui rendent le jeu trop facile ou les options trop similaires. Mettre une contrainte de distance minimale entre les options affichées.

---

## 9. Roadmap Suggérée

### V1 — MVP
- [ ] Accès PhotoKit et indexation des photos GPS
- [ ] Géocodage inverse avec cache local
- [ ] Algorithme de clustering géographique
- [ ] Mode Challenge basique (QCM, score, chrono)
- [ ] Écran de révélation simple (carte + infos)
- [ ] Écran récapitulatif

### V2 — Enrichissement
- [ ] Mode Souvenir avec révélation cinématique complète
- [ ] Diaporama des photos du même voyage sur l'écran de révélation
- [ ] Sélection de voyage/année avant la partie
- [ ] Distance depuis le domicile (configurable dans les réglages)
- [ ] Filtres : uniquement certains pays, certaines années

### V3 — Social & Extras
- [ ] Multijoueur local (tour par tour)
- [ ] Game Center integration (achievements, leaderboards)
- [ ] Partage du récapitulatif de partie

---

## 10. Ressources & Références

- [Documentation PhotoKit — Apple Developer](https://developer.apple.com/documentation/photokit)
- [Documentation MapKit pour tvOS](https://developer.apple.com/documentation/mapkit)
- [SwiftUI sur tvOS — Apple Developer](https://developer.apple.com/tutorials/swiftui)
- [CLGeocoder Reference](https://developer.apple.com/documentation/corelocation/clgeocoder)
- [SwiftData (cache local)](https://developer.apple.com/documentation/swiftdata)
- [Human Interface Guidelines — tvOS](https://developer.apple.com/design/human-interface-guidelines/apple-tv)

---

*Document rédigé le 14 mars 2026 — Version 1.0*
