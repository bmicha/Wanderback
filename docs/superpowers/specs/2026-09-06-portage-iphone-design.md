# Portage iPhone de Wanderback — Design

**Date** : 2026-09-06
**Statut** : validé, à implémenter

## Objectif

Rendre Wanderback jouable sur iPhone, en portrait, avec la même base de code partagée
que les versions tvOS, macOS et iPadOS existantes. Distribution via TestFlight iOS,
même fiche App Store Connect et même procédure archive → altool.

## Cadrage validé

- **Portrait uniquement sur iPhone** — c'est la tenue naturelle du téléphone, et
  beaucoup de photos de voyage sont elles-mêmes en portrait. L'iPad garde son verrou
  paysage.
- **Pas de nouvelle cible.** Le bundle ID `com.bastien.Wanderback` est partagé et
  App Store Connect n'accepte qu'un seul binaire iOS par fiche : deux cibles iOS avec
  le même bundle ID sont impossibles. La cible iOS existante devient universelle.
- **La cible `WanderbackPad` est renommée `WanderbackiOS`** — elle ne sert plus le
  seul iPad.
- **iOS 26.0 minimum**, inchangé : aligné sur l'iPad, le Mac et l'Apple TV, et requis
  par le code existant (`MKReverseGeocodingRequest`).
- **iPhone et iPad se distinguent à l'exécution** (idiom), pas à la compilation :
  ils partagent le même binaire, donc aucun `#if` ne peut les séparer. Les `#if
  os(iOS)` existants, qui séparent iOS des autres plateformes, restent valables.
- **Livrable : upload TestFlight iPhone (build 5).**

## Approche retenue

**Échelle résolue au lancement + branches « téléphone » dans les vues existantes**
(option A validée) :

- `Theme.scale` cesse d'être une constante `#if` et se résout au premier accès selon
  l'idiom. Les ~300 appels `.scaled` du projet ne changent pas d'une ligne.
- Un helper `Device.isPhone` permet aux vues partagées d'écrire `if Device.isPhone`
  sans `#if` autour, pour que les branches de layout restent lisibles.
- Aucune vue dupliquée : les écrans restent les mêmes, seuls quelques conteneurs
  changent d'axe.

Alternatives écartées :

- **Vues iPhone dédiées** (`PhoneHomeView`, `PhoneGameView`…) : liberté de design
  totale, mais duplication de la logique d'écran et dérive garantie dès la première
  évolution.
- **Échelle responsive continue** dérivée de la largeur du canvas, remplaçant les
  trois constantes de `Theme.scale` : élégant, mais cela re-teste tvOS, macOS et iPad
  pour un gain nul aujourd'hui. Retenu comme chantier ultérieur — cf. « Suites
  possibles ».

## Le vrai travail : des largeurs fixes aux largeurs fluides

Le design est calibré sur un canvas TV 1920×1080 et `.scaled` ramène chaque mesure à
l'échelle de la plateforme. Ce modèle homothétique tient sur Mac (fenêtre ~1280 pt,
soit 0,67 du canvas, pour un `scale` de 0,62) et sur iPad (~1210 pt, soit 0,63, pour
un `scale` de 0,7). Il **casse sur iPhone en portrait** : 393 / 1920 = 0,20, ce qui
donnerait un titre de carte réponse à 5,7 pt.

La raison est que l'échelle homothétique confond deux choses distinctes :

- la **taille de texte**, qui dépend de la distance de lecture — or un iPhone se
  regarde d'aussi près qu'un iPad, donc sa typo doit rester dans les mêmes eaux ;
- la **largeur disponible**, qui, elle, est deux fois moindre que sur iPad.

D'où le parti retenu : `Theme.scale = 0,58` sur iPhone (proche du 0,7 iPad — titre de
carte à 16 pt, pays à 12 pt, marge haute à 18 pt), et **conversion des largeurs fixes
calquées sur le canvas en largeurs fluides**. C'est là que se trouve l'essentiel du
travail, pas dans le facteur d'échelle.

`0,58` est une valeur de départ, à affiner à l'œil sur l'appareil réel.

## Composants

### 1. Réglages de la cible

- Renommage `WanderbackPad` → `WanderbackiOS` : `name` et `productName` du
  `PBXNativeTarget`, libellé de la `XCConfigurationList`, commentaires du pbxproj, et
  renommage du scheme partagé `WanderbackPad.xcscheme` → `WanderbackiOS.xcscheme`.
  La cible n'a aucun dossier de sources propre : ~10 occurrences au total.
  `xcuserdata/` n'est pas versionné et ne demande aucun traitement.
  `PRODUCT_NAME = Wanderback` est inchangé — rien ne bouge côté utilisateur ni côté
  App Store Connect.
- `TARGETED_DEVICE_FAMILY` : `2` → `1,2` sur les deux configurations.
- `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` :
  `UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown`.
  La clé `UISupportedInterfaceOrientations` existante garde ses 4 orientations : elle
  s'applique à l'iPad, où les 4 sont exigées pour le multitâche (ITMS-90474).
- Nouveau color set `LaunchBackgroundColor` (`#131226`, le `Theme.backgroundBottom`)
  dans `Assets.xcassets`, pour que le lancement iPhone ne flashe pas en blanc.
  **Amendement (constaté à l'implémentation)** : il n'existe pas de build setting
  `INFOPLIST_KEY_UILaunchScreen_UIColorName` — le mécanisme `INFOPLIST_KEY_*` ne
  remplit que des clés de premier niveau, or `UILaunchScreen` est un dictionnaire.
  La couleur passe donc par un Info.plist partiel `Config/WanderbackiOS-Info.plist`
  (hors du dossier synchronisé `Wanderback/`), désigné par `INFOPLIST_FILE` et
  fusionné avec les clés que `GENERATE_INFOPLIST_FILE` continue de générer.
  `LaunchScreen.storyboard` est un fichier tvOS (`targetRuntime="AppleTV"`) et ne
  concerne pas cette cible, qui utilise `UILaunchScreen_Generation`.
- `ASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-iOS"` : inchangé. Le jeu single-size
  1024 sans canal alpha convient à l'iPhone comme à l'iPad.

### 2. Verrou d'orientation

`OrientationLockDelegate` branche sur l'idiom : `.portrait` sur iPhone, `.landscape`
sur iPad. Le commentaire du fichier, qui affirme aujourd'hui « le design est paysage
seul », est réécrit.

### 3. `Device.isPhone`

Nouveau fichier `Wanderback/Platform/Device.swift` — un seul point de vérité :

```swift
enum Device {
    /// Vrai uniquement sur iPhone. Faux sur iPad, Mac et Apple TV.
    static let isPhone: Bool = {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }()
}
```

Compilé sur toutes les plateformes — il retourne `false` hors iOS — pour que les vues
partagées puissent écrire `if Device.isPhone` sans `#if` autour et garder des branches
de layout lisibles.

### 4. `Theme.scale`

```swift
#if os(macOS)
static let scale: CGFloat = 0.62
#elseif os(iOS)
static let scale: CGFloat = Device.isPhone ? 0.58 : 0.7
#else
static let scale: CGFloat = 1.0
#endif
```

`static let` évaluée une fois au premier accès : `.scaled` reste une extension
`CGFloat` sans contexte SwiftUI, et aucun appel existant ne change.

### 5. Layouts en portrait

Convention de lecture : les changements notés `A → B` sont en **unités du canvas de
design** (avant `.scaled`) ; les diagnostics chiffrés (« ~344 pt », « 522 pt ») sont en
**points réels** sur un iPhone de 393 pt de large.

**`GameView`**

- `topBar` : sur iPhone, le logo « WANDERBACK » est retiré — il ne sert à rien en cours
  de partie et occupe ~130 pt sur les 393 disponibles. Cela supprime au passage le
  `#if os(iOS) .padding(.leading, 44)` qui n'existait que pour éviter la croix
  « fermer ». Libellé de round abrégé en « 3/10 », `spacing` 32 → 18.
- `scrim` : les stops `0.18` / `0.52` sont calés sur un canvas paysage → `0.10` / `0.66`
  sur iPhone. En portrait la zone de réponses est proportionnellement plus haute, et le
  milieu de la photo n'a pas à être assombri.
- `bottomSection` : `padding(.horizontal, 56 → 24)`.

**`AnswerOptionsView`**

Le corps de la carte est extrait dans une sous-vue `answerCard(option:index:)` ; le
conteneur devient un `Grid` 2×2 sur iPhone et reste un `HStack` ailleurs. Les
modificateurs macOS portés par le conteneur (`macMoveCommand`, focus initial via
`onChange`, `macShortcutAction`) sont inchangés. Cible tactile résultante ~180×62 pt,
très au-dessus des 44 pt recommandés par Apple.

**`RevealView`**

- `vignette` : `startRadius: 200` / `endRadius: 1200` sont des points **bruts, non mis
  à l'échelle**. Sur un écran 393×852 (demi-diagonale ~470 pt) le dégradé ne se termine
  jamais : la vignette n'assombrit pas les bords, elle pose un voile uniforme. → 60 /
  440 sur iPhone. Le même défaut existe en fenêtre Mac réduite ; il n'est pas corrigé
  ici, pour ne pas modifier le rendu macOS dans ce lot.
- `centerContent` : `padding(.top, 280 → 190)`, `padding(.horizontal, 100 → 24)`,
  padding interne `70 → 32`, taille du nom du lieu `104 → 76`.
- Rangée basse : les vignettes seules font ~344 pt, le `HStack(vignettes, Spacer,
  bouton)` ne tient pas. → `VStack` sur iPhone : rangée de vignettes (`148×100` →
  `110×74`) avec le libellé « photos du même jour » **sous** elles plutôt qu'à leur
  droite, puis le bouton.

**`SummaryView`**

- `statsLine` : les trois stats cumulent ~435 pt contre 393 disponibles → `VStack` sur
  iPhone.
- « Rejouer » / « Changer de mode » → `VStack` sur iPhone.

**`HomeView`**

- `modeSelection` : `HStack` → `VStack`.
- `modeTileLabel` : sur iPhone l'icône passe **à gauche** du texte plutôt qu'au-dessus
  (une tuile pleine largeur avec l'icône empilée gaspille ~40 pt de hauteur), et
  `frame(width: (500 - 2 * 34).scaled)` → `maxWidth: .infinity`.
- `roundsSelection` et `statsRow` tiennent tels quels (~238 pt) — à confirmer à l'œil.

**`LoadingView`**

`progressBar.frame(width: 900.scaled)` vaut 522 pt, plus large que l'écran →
`maxWidth: .infinity` + `padding(.horizontal, 40.scaled)` sur iPhone.

**`NotEnoughPlacesView`** et **`ContentView.errorView`**

`padding(.horizontal, 200.scaled)` laisse 232 pt de marges pour 161 pt de texte utile →
`24.scaled` sur iPhone. Les deux boutons de `NotEnoughPlacesView` passent en `VStack`.

**`ContentView`** — la croix « fermer » compilée sous `#if os(iOS)` fonctionne telle
quelle : elle est dans un overlay qui respecte la safe area, donc elle se place sous la
Dynamic Island. Aucun changement.

### 6. Ce qui ne change pas

- Flux de données (`PhotoIndexer` → `ClusteringService` → `GeocoderService` →
  `QuestionGenerator` → ViewModels → Views) : identique.
- `LocationCache` (SwiftData) : store local à l'appareil, l'iPhone reconstruit son
  index au premier lancement.
- Retour visuel à l'appui (`configuration.isPressed` dans les trois `ButtonStyle`) :
  déjà en place depuis le portage iPad.
- Helpers `mac*` : no-op sur iOS, inchangés.
- Cibles tvOS et macOS et leurs procédures TestFlight : non modifiées.

## Validation

Le repo n'a aucun test (le `WanderbackTests` mentionné dans le README n'existe pas), et
la mise en page ne se teste pas utilement en unitaire. La validation est visuelle, en
réutilisant les flags de debug déjà en place — `-demoMode`, `-noMosaic`,
`-screen game|reveal|summary` :

1. Captures des 6 écrans au simulateur sur **iPhone 17** (393×852), **iPhone 17 Pro
   Max** (440×956) et **iPhone SE 3** (375×667). Le SE 3 est le pire cas : c'est le
   plus petit appareil supporté par iOS 26, et il a 185 pt de hauteur de moins que
   l'iPhone 17 — c'est lui qui contraint la hauteur cumulée de `HomeView`.
2. Ajustement de `Theme.scale` et des paddings à l'œil.
3. **Non-régression** : une capture iPad et une macOS, pour vérifier que
   `Device.isPhone` n'a rien déplacé ailleurs.
4. Validation sur l'iPhone réel — son UDID doit d'abord être enregistré au portail
   développeur, comme l'a été « iPad de Bastien ».

## Livraison

Build 5, selon la procédure établie :

1. `CURRENT_PROJECT_VERSION` 4 → 5 dans les 6 emplacements du pbxproj (2 configs ×
   3 cibles), la numérotation restant partagée entre plateformes.
2. `xcodebuild archive -scheme WanderbackiOS -destination 'generic/platform=iOS'` avec
   les trois flags d'authentification par clé API `MABCCJ4S35`.
3. `xcodebuild -exportArchive` avec `ExportOptions.plist` (`app-store-connect`,
   `automatic`, team `XKFAS389Q8`).
4. `xcrun altool --upload-app -f <export>/Wanderback.ipa -t ios --apiKey MABCCJ4S35
   --apiIssuer a6ac781b-dc96-4846-a507-ca104b8d7782`.

Travail mené sur la branche `feature/portage-iphone`, intégré par PR.

## Hors périmètre

- Captures d'écran App Store iPhone (TestFlight n'en exige pas).
- Raccourcis clavier (Magic Keyboard) : les helpers `mac*` restent no-op sur iOS.
- Haptique, Dynamic Island, widgets, Live Activities.
- Correction de la vignette `RevealView` en fenêtre Mac réduite.
- Mode paysage sur iPhone.

## Suites possibles

- **Échelle responsive continue** (option C écartée ci-dessus) : remplacer les trois
  constantes de `Theme.scale` par une échelle dérivée de la taille réelle du canvas,
  et les paddings calqués sur le canvas TV par des mesures relatives. Cela supprimerait
  la plupart des branches `Device.isPhone` introduites ici, au prix d'une
  re-validation visuelle des quatre plateformes. À traiter comme une passe
  d'optimisation dédiée, pas dans ce lot.
