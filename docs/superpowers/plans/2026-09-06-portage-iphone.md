# Portage iPhone — Plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUISE — utiliser superpowers:subagent-driven-development (recommandé) ou superpowers:executing-plans pour dérouler ce plan tâche par tâche. Les étapes utilisent la syntaxe checkbox (`- [ ]`).

**Objectif :** rendre Wanderback jouable sur iPhone en portrait, à partir de la cible iOS existante devenue universelle, jusqu'à un build TestFlight.

**Architecture :** la cible `WanderbackPad` est renommée `WanderbackiOS` et passe en `TARGETED_DEVICE_FAMILY = 1,2`. iPhone et iPad partageant désormais le même binaire, ils se distinguent à l'exécution via `Device.isPhone` (idiom) et non par `#if`. `Theme.scale` vaut 0,58 sur iPhone, et les largeurs fixes calquées sur le canvas TV 1920×1080 deviennent fluides.

**Stack :** Swift 5 / SwiftUI, Xcode 27 bêta (`/Applications/Xcode-beta.app`), simulateurs iOS 27, `xcodebuild` + `simctl`, `altool` pour TestFlight.

**Spec :** `docs/superpowers/specs/2026-09-06-portage-iphone-design.md`

## Contraintes globales

- **Langue** : tout le code, les commentaires et les messages de commit sont en français, comme le reste du repo.
- **iOS 26.0 minimum** (`IPHONEOS_DEPLOYMENT_TARGET`), inchangé.
- **Bundle ID** `com.bastien.Wanderback`, **team** `XKFAS389Q8` : identiques sur les 4 cibles, ne jamais les modifier.
- **Sources 100 % partagées** : aucun fichier de vue dupliqué pour l'iPhone. Le dossier `Wanderback/` est un `PBXFileSystemSynchronizedRootGroup` — tout nouveau `.swift` qu'on y dépose devient automatiquement membre des trois cibles, sans manipulation du pbxproj.
- **`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`** doit préfixer chaque commande `xcodebuild` / `xcrun` : le Xcode par défaut de la machine est un Command Line Tools sans SDK. Voir la mémoire `machine-macos27-beta-xcode-launch`.
- **Ne pas toucher au rendu tvOS et macOS.** Toute branche introduite est gardée par `Device.isPhone`, qui vaut `false` hors iPhone. La tâche 9 le vérifie.
- **Unités** : les valeurs `A → B` de ce plan sont en unités du canvas de design (avant `.scaled`) ; les diagnostics chiffrés en « pt » sont des points réels calculés sur une **base de 393 pt de large**, la largeur d'un iPhone standard récent. C'est une borne prudente : l'iPhone 17 est un peu plus large (402 pt). Le cas réellement contraignant est le SE 3, à 375 pt.
- **Simulateurs de référence** (déjà créés sur la machine) : `iPhone 17` (402×874 pt, capture 1206×2622 px), `iPhone 17 Pro Max` (440×956 pt), `iPhone SE (3rd generation)` (375×667 pt — le pire cas).

## Note sur le cycle de validation

Ce repo **n'a aucun test** et le TDD ne s'applique pas à des changements de mise en page SwiftUI : il n'existe pas d'assertion utile sur « la grille tient dans 393 pt ». Le cycle rouge/vert est donc remplacé, à chaque tâche, par :

1. **build** — `xcodebuild build` est le garde-fou automatique réel : les sources étant partagées entre quatre cibles, une régression de compilation sur tvOS ou macOS est détectée immédiatement ;
2. **capture** — installation et lancement sur simulateur avec les flags de debug existants, puis capture PNG à regarder ;
3. **commit**.

Les captures sont écrites dans le scratchpad de session, **jamais dans le repo** (`docs/appstore/` ne reçoit que les captures App Store définitives).

---

### Tâche 1 : cible universelle `WanderbackiOS` + outil de capture

Livrable : l'app se construit, s'installe et se lance sur un simulateur **iPhone**, et une commande unique produit une capture d'un écran donné.

**Fichiers :**
- Modifier : `Wanderback.xcodeproj/project.pbxproj`
- Renommer : `Wanderback.xcodeproj/xcshareddata/xcschemes/WanderbackPad.xcscheme` → `WanderbackiOS.xcscheme`
- Créer : `Wanderback/Assets.xcassets/LaunchBackgroundColor.colorset/Contents.json`
- Créer : `scripts/shot-ios.sh`

**Interfaces :**
- Produit : le scheme `WanderbackiOS`, utilisé par toutes les tâches suivantes et par la tâche 10 (archive).
- Produit : `scripts/shot-ios.sh <simulateur> <sortie.png> [args...]`, la boucle de validation de toutes les tâches suivantes.

- [ ] **Étape 1 : renommer la cible dans le pbxproj**

Remplacer les 10 occurrences de `WanderbackPad` par `WanderbackiOS`. Elles se répartissent en : le commentaire et la valeur `name`/`productName` du `PBXNativeTarget` `AD0000000000000000000001`, le libellé de l'exception de membership `AD0000000000000000000009`, les commentaires de la `XCConfigurationList` `AD0000000000000000000006`, et l'entrée de la liste des cibles du projet.

```bash
cd "$(git rev-parse --show-toplevel)"
sed -i '' 's/WanderbackPad/WanderbackiOS/g' Wanderback.xcodeproj/project.pbxproj
git mv Wanderback.xcodeproj/xcshareddata/xcschemes/WanderbackPad.xcscheme \
       Wanderback.xcodeproj/xcshareddata/xcschemes/WanderbackiOS.xcscheme
sed -i '' 's/WanderbackPad/WanderbackiOS/g' Wanderback.xcodeproj/xcshareddata/xcschemes/WanderbackiOS.xcscheme
grep -c WanderbackPad Wanderback.xcodeproj/project.pbxproj  # doit afficher 0
```

`PRODUCT_NAME = Wanderback` ne doit **pas** être touché : c'est le nom vu par l'utilisateur et par App Store Connect. Vérifier après le `sed` :

```bash
grep -n "PRODUCT_NAME" Wanderback.xcodeproj/project.pbxproj
```

- [ ] **Étape 2 : rendre la cible universelle et déclarer le portrait iPhone**

Dans les **deux** configurations (`AD0000000000000000000007` Debug et `AD0000000000000000000008` Release) :

```
TARGETED_DEVICE_FAMILY = "1,2";
```

et ajouter, juste après la ligne `INFOPLIST_KEY_UISupportedInterfaceOrientations` existante :

```
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown";
```

Ne **pas** modifier `INFOPLIST_KEY_UISupportedInterfaceOrientations` : ses 4 orientations s'appliquent à l'iPad, où elles sont exigées pour le multitâche (ITMS-90474).

- [ ] **Étape 3 : couleur de fond de l'écran de lancement**

Créer `Wanderback/Assets.xcassets/LaunchBackgroundColor.colorset/Contents.json` :

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0x26",
          "green" : "0x12",
          "red" : "0x13"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

C'est `Theme.backgroundBottom` (`#131226`).

Il **n'existe pas** de build setting `INFOPLIST_KEY_UILaunchScreen_UIColorName` : le mécanisme `INFOPLIST_KEY_*` ne remplit que des clés de premier niveau, et `UILaunchScreen` est un dictionnaire. La seule setting de cette famille que Xcode connaît est `INFOPLIST_KEY_UILaunchScreen_Generation` (vérifié dans `CoreBuildSystem.xcspec`). Il faut donc un Info.plist partiel, fusionné avec les clés générées.

Créer `Config/WanderbackiOS-Info.plist` — **hors** du dossier `Wanderback/`, qui est un groupe synchronisé où un `.plist` serait embarqué comme ressource dans les trois cibles :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>UILaunchScreen</key>
	<dict>
		<key>UIColorName</key>
		<string>LaunchBackgroundColor</string>
	</dict>
</dict>
</plist>
```

puis, dans les deux configurations iOS :

```
INFOPLIST_FILE = "Config/WanderbackiOS-Info.plist";
```

`GENERATE_INFOPLIST_FILE = YES` reste actif : Xcode fusionne ce fichier avec les clés qu'il génère. Recette vérifiée sur un build propre — le binaire obtient `UILaunchScreen = { UIColorName = LaunchBackgroundColor }` **et** conserve `UISupportedInterfaceOrientations~iphone` et `NSPhotoLibraryUsageDescription`.

Vérifier après le build :

```bash
/usr/libexec/PlistBuddy -c "Print :UILaunchScreen" \
  .build-sim/Build/Products/Debug-iphonesimulator/Wanderback.app/Info.plist
```

Attendu : `Dict { UIColorName = LaunchBackgroundColor }`, et **non** un dict vide.

- [ ] **Étape 4 : créer l'outil de capture**

Créer `scripts/shot-ios.sh` :

```bash
#!/bin/bash
# Construit la cible iOS, l'installe sur un simulateur, la lance avec les
# arguments donnés et capture l'écran.
#
#   scripts/shot-ios.sh "iPhone 17" /tmp/game.png -demoMode -noMosaic -screen game
#
# Écrans atteignables : -screen game | reveal | summary (avec -demoMode).
# Sans -screen : l'accueil. -noMosaic masque les photos personnelles du fond.
set -euo pipefail

SIM="${1:?usage: shot-ios.sh <simulateur> <sortie.png> [args de lancement...]}"
OUT="${2:?usage: shot-ios.sh <simulateur> <sortie.png> [args de lancement...]}"
shift 2

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD="${DD:-$ROOT/.build-sim}"

xcodebuild -project "$ROOT/Wanderback.xcodeproj" -scheme WanderbackiOS \
  -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath "$DD" build > /dev/null

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b > /dev/null
xcrun simctl install "$SIM" "$DD/Build/Products/Debug-iphonesimulator/Wanderback.app"
xcrun simctl terminate "$SIM" com.bastien.Wanderback 2>/dev/null || true
xcrun simctl launch "$SIM" com.bastien.Wanderback "$@" > /dev/null

# Laisse le temps au premier rendu SwiftUI (et à l'animation d'apparition)
sleep 4

xcrun simctl io "$SIM" screenshot "$OUT"
echo "→ $OUT"
```

```bash
chmod +x scripts/shot-ios.sh
echo ".build-sim/" >> .gitignore
```

Si l'environnement d'exécution refuse un `sleep` au premier plan, lancer le script en tâche de fond plutôt que de retirer l'attente : sans elle, la capture arrive avant le premier rendu et donne un écran noir.

- [ ] **Étape 5 : vérifier que l'app se lance sur iPhone**

```bash
scripts/shot-ios.sh "iPhone 17" /tmp/t1-accueil.png -demoMode -noMosaic
```

Attendu : `** BUILD SUCCEEDED **` puis un PNG. L'écran sera **visiblement cassé** — contenu débordant, texte trop gros, tuiles hors cadre : c'est normal et c'est la référence « avant » du portage.

La capture sera encore en **paysage** : `OrientationLockDelegate` force `.landscape` pour tout iOS et court-circuite l'Info.plist. Ce verrou est levé en tâche 2, qui est propriétaire de ce fichier. Le critère de cette étape est donc uniquement : l'app se construit, s'installe, se lance et ne plante pas.

- [ ] **Étape 6 : commit**

```bash
git add -A
git commit -m "Cible iOS universelle WanderbackiOS, portrait iPhone, outil de capture simulateur"
```

---

### Tâche 2 : `Device.isPhone`, échelle iPhone, verrou portrait

Livrable : l'app s'affiche à la bonne taille typographique sur iPhone, verrouillée en portrait, avec un fond de scène correct.

**Fichiers :**
- Créer : `Wanderback/Platform/Device.swift`
- Modifier : `Wanderback/DesignSystem/Theme.swift` (`Theme.scale`, `SceneBackground`)
- Modifier : `Wanderback/Platform/OrientationLock.swift`

**Interfaces :**
- Produit : `Device.isPhone` (`Bool` statique), consommé par toutes les tâches 3 à 8.

- [ ] **Étape 1 : créer `Device.swift`**

```swift
#if os(iOS)
import UIKit
#endif

/// Distinctions d'appareil qui ne peuvent pas se faire à la compilation : depuis le
/// portage iPhone, iPhone et iPad partagent le même binaire iOS, donc aucun `#if` ne
/// les sépare. Un seul point de vérité, pour que les vues partagées puissent écrire
/// `if Device.isPhone` sans `#if` autour et garder des branches de layout lisibles.
enum Device {
    /// Vrai uniquement sur iPhone. Faux sur iPad, Mac et Apple TV.
    static let isPhone: Bool = {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }()
}
```

Aucune manipulation du pbxproj : le dossier `Wanderback/` est synchronisé, le fichier rejoint les trois cibles tout seul.

- [ ] **Étape 2 : échelle iPhone**

Dans `Wanderback/DesignSystem/Theme.swift`, remplacer le bloc `// MARK: - Échelle plateforme`. Avant :

```swift
    #if os(macOS)
    static let scale: CGFloat = 0.62
    #elseif os(iOS)
    static let scale: CGFloat = 0.7
    #else
    static let scale: CGFloat = 1.0
    #endif
```

Après :

```swift
    /// L'UI est calibrée pour un canvas TV 1920×1080 regardé à 3 m ; en fenêtre
    /// Mac (~1280 pt) et sur iPad (~1200-1400 pt) typo et espacements sont
    /// réduits d'un facteur global.
    ///
    /// Sur iPhone, l'homothétie ne tient plus : 393 / 1920 donnerait un titre de
    /// carte réponse à 6 pt. Un téléphone se regarde d'aussi près qu'un iPad, donc
    /// sa typo reste dans les mêmes eaux ; ce qui manque, c'est la largeur — traitée
    /// écran par écran par des layouts fluides, pas par le facteur d'échelle.
    #if os(macOS)
    static let scale: CGFloat = 0.62
    #elseif os(iOS)
    static let scale: CGFloat = Device.isPhone ? 0.58 : 0.7
    #else
    static let scale: CGFloat = 1.0
    #endif
```

Le commentaire d'origine placé au-dessus du bloc est remplacé par celui-ci.

- [ ] **Étape 3 : fond de scène**

`SceneBackground` utilise `endRadius: 1400` en points **bruts**. Sur un iPhone (demi-diagonale ~470 pt) le dégradé ne se termine jamais : le fond reste uniformément proche de `backgroundTop`. Dans `Theme.swift` :

```swift
struct SceneBackground: View {
    var body: some View {
        RadialGradient(
            colors: [Theme.backgroundTop, Theme.backgroundBottom],
            center: .init(x: 0.5, y: 0.25),
            startRadius: 0,
            // Rayon en points bruts : il doit couvrir l'écran, pas le canvas de design
            endRadius: Device.isPhone ? 520 : 1400
        )
        .ignoresSafeArea()
    }
}
```

- [ ] **Étape 4 : verrou portrait sur iPhone**

Remplacer le contenu de `Wanderback/Platform/OrientationLock.swift` :

```swift
#if os(iOS)
import UIKit

/// L'Info.plist déclare les 4 orientations pour l'iPad — exigence App Store pour le
/// multitâche (ITMS-90474) — et le portrait seul pour l'iPhone. Ce délégué verrouille
/// l'orientation à l'exécution en plein écran : portrait sur iPhone, paysage sur iPad,
/// chaque design n'étant dessiné que pour l'une des deux. En fenêtre iPadOS 26,
/// l'orientation ne s'applique pas et le redimensionnement reste libre.
final class OrientationLockDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Device.isPhone ? .portrait : .landscape
    }
}
#endif
```

- [ ] **Étape 5 : build des quatre cibles**

C'est le premier point où une régression tvOS/macOS est possible (`Theme.scale` et `SceneBackground` sont partagés). Les quatre doivent passer :

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
for s in "Wanderback:generic/platform=tvOS" \
         "WanderbackMac:generic/platform=macOS" \
         "WanderbackiOS:generic/platform=iOS"; do
  xcodebuild -project Wanderback.xcodeproj -scheme "${s%%:*}" \
    -destination "${s#*:}" -derivedDataPath .build-sim build 2>&1 | tail -1
done
```

Attendu : trois `** BUILD SUCCEEDED **`.

- [ ] **Étape 6 : capture**

```bash
scripts/shot-ios.sh "iPhone 17" /tmp/t2-accueil.png -demoMode -noMosaic
```

Attendu, dans cet ordre de priorité :

1. **La capture est en portrait** (1206×2622 px sur iPhone 17) — c'est ici que le verrou d'orientation de la tâche 1 est levé, et c'est le critère bloquant de cette tâche ;
2. la typo est à une taille plausible pour un téléphone (le mot « WANDERBACK » du titre tient dans la largeur) ;
3. le fond montre un vrai dégradé radial, sombre vers les bords.

Les tuiles de mode débordent encore latéralement — c'est la tâche 7.

- [ ] **Étape 7 : commit**

```bash
git add -A
git commit -m "Device.isPhone, échelle iPhone 0,58, verrou portrait et fond de scène adapté"
```

---

### Tâche 3 : grille de réponses 2×2

Livrable : les 4 cartes réponse s'affichent en grille 2×2 sur iPhone, en rangée ailleurs.

**Fichiers :**
- Modifier : `Wanderback/Views/AnswerOptionsView.swift`

**Interfaces :**
- Consomme : `Device.isPhone` (tâche 2).

- [ ] **Étape 1 : extraire la carte en sous-vue**

Dans `AnswerOptionsView`, sortir le contenu du `ForEach` dans une méthode, pour ne pas le dupliquer entre les deux conteneurs :

```swift
    @ViewBuilder
    private func answerCard(_ option: LocationCluster, index: Int) -> some View {
        Button {
            onSelect(option)
        } label: {
            VStack(alignment: .leading, spacing: 6.scaled) {
                Text(option.displayName)
                    .font(.system(size: 28.scaled, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(option.country)
                    .font(.system(size: 21.scaled))
                    .opacity(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28.scaled)
            .padding(.vertical, 24.scaled)
        }
        .buttonStyle(AnswerCardButtonStyle())
        .macFocusable()
        .focused($focusedOption, equals: option.id)
        .macFocusOnHover($focusedOption, equals: option.id)
        .macKeyboardShortcut(Character("\(index + 1)"))
    }
```

- [ ] **Étape 2 : brancher les deux conteneurs**

Remplacer le `HStack` du `body` par :

```swift
    var body: some View {
        optionsContainer
        #if os(macOS)
        // … tout le bloc de modificateurs macOS existant, inchangé …
        #endif
    }

    /// Sur iPhone en portrait, les 4 cartes ne tiennent pas sur une rangée
    /// (~85 pt chacune) : grille 2×2. Ailleurs, la rangée du design d'origine.
    @ViewBuilder
    private var optionsContainer: some View {
        if Device.isPhone {
            Grid(horizontalSpacing: 12.scaled, verticalSpacing: 12.scaled) {
                ForEach(Array(stride(from: 0, to: options.count, by: 2)), id: \.self) { row in
                    GridRow {
                        // Les cartes gardent l'identité de leur donnée (comme la
                        // branche rangée) et non leur position : un `id: \.self`
                        // sur l'index ferait fuiter d'un round à l'autre tout
                        // `@State` porté par une carte.
                        ForEach(
                            Array(options[row ..< min(row + 2, options.count)].enumerated()),
                            id: \.element.id
                        ) { offset, option in
                            answerCard(option, index: row + offset)
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 24.scaled) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    answerCard(option, index: index)
                }
            }
        }
    }
```

Le bloc `#if os(macOS)` (le `macMoveCommand`, le `onChange(of: options.map(\.id), initial: true)` qui pose le focus initial, et le `macShortcutAction(.return)`) reste attaché au conteneur, mot pour mot.

- [ ] **Étape 3 : build**

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project Wanderback.xcodeproj -scheme WanderbackiOS \
  -destination 'generic/platform=iOS' -derivedDataPath .build-sim build 2>&1 | tail -1
xcodebuild -project Wanderback.xcodeproj -scheme Wanderback \
  -destination 'generic/platform=tvOS' -derivedDataPath .build-sim build 2>&1 | tail -1
```

- [ ] **Étape 4 : capture**

```bash
scripts/shot-ios.sh "iPhone 17" /tmp/t3-jeu.png -demoMode -noMosaic -screen game
```

Attendu : 4 cartes en 2 lignes de 2, de largeur égale, chacune d'environ 180×62 pt. Les noms de ville longs sont réduits par `minimumScaleFactor(0.7)` plutôt que tronqués.

- [ ] **Étape 5 : commit**

```bash
git add -A
git commit -m "Grille de réponses 2x2 sur iPhone, rangée de 4 ailleurs"
```

---

### Tâche 4 : écran de jeu

Livrable : la barre haute tient dans la largeur d'un iPhone et le scrim assombrit la bonne zone.

**Fichiers :**
- Modifier : `Wanderback/Views/GameView.swift`

**Interfaces :**
- Consomme : `Device.isPhone` (tâche 2).

- [ ] **Étape 1 : dégraisser la barre haute**

Le logo « WANDERBACK », le libellé « Round 3/10 », l'anneau chrono et le score cumulent ~341 pt pour 321 pt utiles sur un iPhone 17. Le logo n'apprend rien en cours de partie : il disparaît sur iPhone, ce qui supprime au passage le `padding(.leading, 44)` qui n'existait que pour éviter la croix « fermer ».

Remplacer `topBar` par :

```swift
    private var topBar: some View {
        HStack {
            // Sur iPhone, la largeur est comptée : le logo cède la place au chrono
            // et au score, et la croix « fermer » (overlay de ContentView) occupe
            // seule le coin haut gauche.
            if !Device.isPhone {
                GradientText(text: "WANDERBACK", size: 28, tracking: -0.5)
            }

            Spacer()

            HStack(spacing: Device.isPhone ? 18.scaled : 32.scaled) {
                // Le numéro courant reste en gras dans les deux variantes
                Text(Device.isPhone
                     ? "\(Text("\(currentRoundNumber)").bold())/\(totalRounds)"
                     : "Round \(Text("\(currentRoundNumber)").bold())/\(totalRounds)")
                    .font(.system(size: 24.scaled))
                    .foregroundStyle(Theme.textSecondary)

                if gameViewModel.mode == .challenge {
                    timerRing

                    Text("\(gameViewModel.score.formatted(.number.grouping(.automatic))) pts")
                        .font(.system(size: 24.scaled, weight: .bold))
                        .foregroundStyle(Theme.amber)
                }
            }
        }
        .padding(.horizontal, Device.isPhone ? 24.scaled : 56.scaled)
        .padding(.vertical, 36.scaled)
    }
```

Supprimer le bloc `#if os(iOS) .padding(.leading, 44.scaled) #endif` et son commentaire, devenus sans objet.

- [ ] **Étape 2 : ajuster le scrim**

Les stops `0.18` / `0.52` sont calés sur un canvas paysage. En portrait, la zone de réponses monte plus haut et le milieu de la photo n'a pas à être assombri :

```swift
    /// Scrim vertical : sombre en haut, transparent au centre, très sombre en bas.
    /// En portrait la zone de réponses occupe une part plus haute de l'écran : le
    /// dégradé bas démarre plus tard pour ne pas voiler le centre de la photo.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: scrimColor.opacity(0.6), location: 0),
                .init(color: .clear, location: Device.isPhone ? 0.10 : 0.18),
                .init(color: .clear, location: Device.isPhone ? 0.66 : 0.52),
                .init(color: scrimColor.opacity(0.92), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
```

- [ ] **Étape 3 : marges de la section basse**

Dans `bottomSection` :

```swift
        .padding(.horizontal, Device.isPhone ? 24.scaled : 56.scaled)
        .padding(.bottom, 44.scaled)
```

- [ ] **Étape 4 : build et capture, sur les deux gabarits extrêmes**

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project Wanderback.xcodeproj -scheme Wanderback \
  -destination 'generic/platform=tvOS' -derivedDataPath .build-sim build 2>&1 | tail -1
scripts/shot-ios.sh "iPhone 17" /tmp/t4-jeu-17.png -demoMode -noMosaic -screen game
scripts/shot-ios.sh "iPhone SE (3rd generation)" /tmp/t4-jeu-se.png -demoMode -noMosaic -screen game
```

Attendu : sur les deux, la barre haute tient sur une seule ligne sans chevauchement entre la croix, le compteur de round, l'anneau chrono et le score ; la grille de réponses est lisible sur un fond suffisamment sombre.

- [ ] **Étape 5 : commit**

```bash
git add -A
git commit -m "Écran de jeu iPhone : barre haute dégraissée, scrim et marges en portrait"
```

---

### Tâche 5 : écran de révélation

Livrable : cartouche, vignette et rangée basse lisibles en portrait.

**Fichiers :**
- Modifier : `Wanderback/Views/RevealView.swift`

**Interfaces :**
- Consomme : `Device.isPhone` (tâche 2).

- [ ] **Étape 1 : corriger la vignette**

`startRadius: 200` / `endRadius: 1200` sont des points **bruts**. Sur un écran de demi-diagonale ~470 pt, le dégradé ne se termine jamais : la vignette pose un voile uniforme au lieu d'assombrir les bords.

```swift
    /// Vignette radiale sombre sur les bords de la carte.
    /// Rayons en points bruts : ils doivent couvrir l'écran, pas le canvas de design.
    private var vignette: some View {
        RadialGradient(
            stops: [
                .init(color: Theme.backgroundBottom.opacity(0.25), location: 0),
                .init(color: Theme.backgroundBottom.opacity(0.4), location: 0.5),
                .init(color: Theme.backgroundBottom.opacity(0.88), location: 1)
            ],
            center: .center,
            startRadius: Device.isPhone ? 60 : 200,
            endRadius: Device.isPhone ? 440 : 1200
        )
        .allowsHitTesting(false)
    }
```

- [ ] **Étape 2 : recadrer le cartouche central**

Dans `centerContent`, quatre valeurs sont calées sur un canvas paysage. Le nom du lieu :

```swift
            Text(round?.correctAnswer.displayName.uppercased() ?? "")
                .font(.system(size: (Device.isPhone ? 76 : 104).scaled, weight: .heavy))
```

et les marges, en bas du même bloc :

```swift
        .padding(.horizontal, (Device.isPhone ? 32 : 70).scaled)   // padding interne du cartouche
        .padding(.vertical, 40.scaled)
        .background { … inchangé … }
        .overlay(… inchangé …)
        .shadow(color: Theme.tileShadow, radius: 30, y: 20)
        .padding(.top, (Device.isPhone ? 190 : 280).scaled)  // sous le pin
        .padding(.horizontal, (Device.isPhone ? 24 : 100).scaled)
```

Les deux `padding(.horizontal)` sont distincts : le premier (70 → 32) est la marge intérieure du cartouche, le second (100 → 24) sa marge par rapport aux bords de l'écran. Ne pas les confondre.

- [ ] **Étape 3 : empiler la rangée basse**

Les 3 vignettes seules font ~344 pt : le `HStack(vignettes, Spacer, bouton)` ne tient pas. Remplacer le dernier `VStack` du `body` par :

```swift
            VStack {
                Spacer()
                if Device.isPhone {
                    // 344 pt de vignettes + le bouton ne tiennent pas sur une rangée
                    VStack(spacing: 20.scaled) {
                        sameDayThumbnails
                        nextButton
                    }
                } else {
                    HStack(alignment: .bottom) {
                        sameDayThumbnails
                        Spacer()
                        nextButton
                    }
                }
            }
            .padding(.horizontal, (Device.isPhone ? 24 : 56).scaled)
            .padding(.bottom, 44.scaled)
            .tvIgnoresSafeArea()
```

- [ ] **Étape 4 : réduire les vignettes et déplacer leur libellé**

Dans `sameDayThumbnails`, la rangée horizontale devient, sur iPhone, une colonne « rangée d'images + libellé dessous » :

```swift
    @ViewBuilder
    private var sameDayThumbnails: some View {
        if !sameDayImages.isEmpty {
            let side: (width: CGFloat, height: CGFloat) =
                Device.isPhone ? (110, 74) : (148, 100)

            let row = HStack(alignment: .bottom, spacing: 14.scaled) {
                ForEach(Array(sameDayImages.enumerated()), id: \.offset) { _, image in
                    Image(platformImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: side.width.scaled, height: side.height.scaled)
                        .clipShape(RoundedRectangle(cornerRadius: 14.scaled))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14.scaled)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 2)
                        )
                }

                // Sur iPhone le libellé passe sous la rangée : à droite, il la
                // pousserait hors de l'écran.
                if !Device.isPhone {
                    Text("photos du\nmême jour")
                        .font(.system(size: 19.scaled))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, 6.scaled)
                }
            }

            Group {
                if Device.isPhone {
                    VStack(spacing: 8.scaled) {
                        row
                        Text("photos du même jour")
                            .font(.system(size: 19.scaled))
                            .foregroundStyle(Theme.textTertiary)
                    }
                } else {
                    row
                }
            }
            .opacity(contentRevealed ? 1 : 0)
        }
    }
```

- [ ] **Étape 5 : build et captures**

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project Wanderback.xcodeproj -scheme Wanderback \
  -destination 'generic/platform=tvOS' -derivedDataPath .build-sim build 2>&1 | tail -1
scripts/shot-ios.sh "iPhone 17" /tmp/t5-reveal-17.png -demoMode -noMosaic -screen reveal
scripts/shot-ios.sh "iPhone SE (3rd generation)" /tmp/t5-reveal-se.png -demoMode -noMosaic -screen reveal
```

Attendu : le badge de résultat en haut, le pin dans le tiers haut de la carte, le cartouche sous lui sans le chevaucher, puis vignettes et bouton empilés en bas sans déborder. Les bords de la carte sont visiblement assombris par la vignette.

Le zoom cinématique dure 1,6 s en mode Challenge et le contenu apparaît avec un délai : les 4 s d'attente du script suffisent, mais si le cartouche est absent de la capture, relancer plutôt qu'allonger l'attente à l'aveugle.

- [ ] **Étape 6 : commit**

```bash
git add -A
git commit -m "Écran de révélation iPhone : vignette corrigée, cartouche recadré, rangée basse empilée"
```

---

### Tâche 6 : écran de résumé

Livrable : stats et boutons empilés, lisibles jusque sur iPhone SE.

**Fichiers :**
- Modifier : `Wanderback/Views/SummaryView.swift`

**Interfaces :**
- Consomme : `Device.isPhone` (tâche 2).

- [ ] **Étape 1 : empiler la ligne de stats**

Les trois stats cumulent ~435 pt contre 393 disponibles.

```swift
    private var statsLine: some View {
        let items = [
            Text("\(Text("\(gameViewModel.correctAnswersCount)/\(rounds.count)").bold()) bonnes réponses"),
            Text("\(Text("\(gameViewModel.totalDistanceKm.formatted(.number.grouping(.automatic))) km").bold()) parcourus"),
            Text("\(Text("\(gameViewModel.countriesVisitedCount)").bold()) \(gameViewModel.countriesVisitedCount > 1 ? "pays visités" : "pays visité")")
        ]

        return Group {
            if Device.isPhone {
                // ~435 pt cumulés : les trois stats ne tiennent pas sur une rangée
                VStack(spacing: 8.scaled) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in item }
                }
            } else {
                HStack(spacing: 56.scaled) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in item }
                }
            }
        }
        .font(.system(size: 25.scaled))
        .foregroundStyle(Theme.textSecondary)
    }
```

- [ ] **Étape 2 : empiler les deux boutons**

Dans le `body`, remplacer le `HStack(spacing: 30.scaled)` qui contient « Rejouer » et « Changer de mode » par un conteneur conditionnel. Les deux boutons et leurs modificateurs sont extraits en propriétés, pour n'être écrits qu'une fois :

```swift
    private var replayButton: some View {
        Button {
            gameViewModel.replay()
        } label: {
            HStack(spacing: 14.scaled) {
                Text("Rejouer")
                Image(systemName: "play.fill")
                    .font(.system(size: 20.scaled))
            }
        }
        .buttonStyle(GradientPillButtonStyle(horizontalPadding: 56, verticalPadding: 20, fontSize: 26))
        .macFocusable()
        .focused($focusedButton, equals: .replay)
        .macFocusOnHover($focusedButton, equals: .replay)
        .macDefaultActionShortcut()
    }

    private var changeModeButton: some View {
        Button("Changer de mode") {
            onChangeMode()
        }
        .buttonStyle(SecondaryPillButtonStyle())
        .macFocusable()
        .focused($focusedButton, equals: .changeMode)
        .macFocusOnHover($focusedButton, equals: .changeMode)
    }

    /// ~352 pt côte à côte, contre 375 pt sur iPhone SE : trop juste une fois
    /// l'effet d'échelle à l'appui appliqué. Empilés sur téléphone.
    @ViewBuilder
    private var summaryButtons: some View {
        if Device.isPhone {
            VStack(spacing: 16.scaled) {
                replayButton
                changeModeButton
            }
        } else {
            HStack(spacing: 30.scaled) {
                replayButton
                changeModeButton
            }
        }
    }
```

Le `body` appelle `summaryButtons`, en conservant à l'identique le bloc `#if !os(iOS) .focusSection() … #endif` qui le suivait.

- [ ] **Étape 3 : build et captures**

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project Wanderback.xcodeproj -scheme Wanderback \
  -destination 'generic/platform=tvOS' -derivedDataPath .build-sim build 2>&1 | tail -1
scripts/shot-ios.sh "iPhone 17" /tmp/t6-resume-17.png -demoMode -noMosaic -screen summary
scripts/shot-ios.sh "iPhone SE (3rd generation)" /tmp/t6-resume-se.png -demoMode -noMosaic -screen summary
```

Attendu : score, sous-titre, trois stats empilées et deux boutons pleins, le tout tenant dans la hauteur du SE sans être coupé.

- [ ] **Étape 4 : commit**

```bash
git add -A
git commit -m "Écran de résumé iPhone : stats et boutons empilés"
```

---

### Tâche 7 : accueil

Livrable : l'accueil tient entièrement dans un écran d'iPhone SE.

**Fichiers :**
- Modifier : `Wanderback/Views/HomeView.swift`

**Interfaces :**
- Consomme : `Device.isPhone` (tâche 2).

- [ ] **Étape 1 : empiler les tuiles de mode**

```swift
    private var modeSelection: some View {
        let tiles = ForEach(GameMode.allCases) { mode in
            Button {
                activate(.mode(mode))
            } label: {
                modeTileLabel(mode)
            }
            .buttonStyle(ModeTileButtonStyle(isSelected: selectedMode == mode, mode: mode))
            .macFocusable()
            .focused($focusedElement, equals: .mode(mode))
            .macFocusOnHover($focusedElement, equals: .mode(mode))
        }

        return Group {
            if Device.isPhone {
                VStack(spacing: 16.scaled) { tiles }
            } else {
                HStack(spacing: 34.scaled) { tiles }
            }
        }
    }
```

- [ ] **Étape 2 : rendre la tuile fluide et compacte**

`frame(width: (500 - 2 * 34).scaled)` est une largeur fixe calquée sur le canvas : elle ne s'adapte pas à l'écran. Et une tuile pleine largeur avec l'icône empilée au-dessus du texte gaspille ~40 pt de hauteur, ce qui compte sur un SE.

```swift
    private func modeTileLabel(_ mode: GameMode) -> some View {
        let icon = Image(systemName: mode.icon)
            .font(.system(size: 24.scaled))
            .foregroundStyle(.white)
            .frame(width: 52.scaled, height: 52.scaled)
            .background(Color.white.opacity(0.25), in: Circle())

        let text = VStack(alignment: .leading, spacing: 6.scaled) {
            Text(mode.title)
                .font(.system(size: 34.scaled, weight: .heavy))
            Text(mode.subtitle)
                .font(.system(size: 22.scaled))
                .foregroundStyle(.white.opacity(0.75))
        }

        return Group {
            if Device.isPhone {
                // Tuile pleine largeur : icône à gauche plutôt qu'au-dessus, pour
                // économiser la hauteur — critique sur iPhone SE (667 pt).
                HStack(spacing: 16.scaled) {
                    icon
                    text
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: 16.scaled) {
                    icon
                    text
                }
                .frame(width: (500 - 2 * 34).scaled, alignment: .leading)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: Device.isPhone ? .infinity : nil, alignment: .leading)
        .padding(Device.isPhone ? 22.scaled : 34.scaled)
    }
```

- [ ] **Étape 3 : resserrer l'espacement vertical de l'accueil**

Cinq blocs séparés par 44 unités de canvas, plus le CTA, ne tiennent pas dans les 647 pt utiles d'un SE. Dans le `body` :

```swift
            VStack(spacing: (Device.isPhone ? 26 : 44).scaled) {
```

et ajouter, sous le `VStack`, une marge latérale que le design TV n'avait pas besoin d'expliciter :

```swift
            .padding(.horizontal, Device.isPhone ? 24.scaled : 0)
```

- [ ] **Étape 4 : build et captures**

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project Wanderback.xcodeproj -scheme Wanderback \
  -destination 'generic/platform=tvOS' -derivedDataPath .build-sim build 2>&1 | tail -1
scripts/shot-ios.sh "iPhone 17" /tmp/t7-accueil-17.png -demoMode -noMosaic
scripts/shot-ios.sh "iPhone SE (3rd generation)" /tmp/t7-accueil-se.png -demoMode -noMosaic
scripts/shot-ios.sh "iPhone 17 Pro Max" /tmp/t7-accueil-max.png -demoMode -noMosaic
```

Attendu : sur les trois, titre, deux tuiles, sélecteur de rounds, ligne de stats et bouton « C'EST PARTI » sont tous visibles sans coupure ni chevauchement. Vérifier en particulier le SE : c'est lui qui décide.

Si l'accueil déborde encore sur SE, ne pas réduire `Theme.scale` (cela rapetisserait tous les écrans) — resserrer l'espacement du `VStack` à 20 unités.

- [ ] **Étape 5 : commit**

```bash
git add -A
git commit -m "Accueil iPhone : tuiles de mode empilées et fluides, espacement resserré"
```

---

### Tâche 8 : écrans de chargement, d'erreur et « pas assez de lieux »

Livrable : les trois écrans secondaires sont lisibles sur iPhone.

**Fichiers :**
- Modifier : `Wanderback/Views/LoadingView.swift`
- Modifier : `Wanderback/Views/NotEnoughPlacesView.swift`
- Modifier : `Wanderback/Views/ContentView.swift` (`errorView`)

**Interfaces :**
- Consomme : `Device.isPhone` (tâche 2).

- [ ] **Étape 1 : barre de progression fluide**

`frame(width: 900.scaled)` vaut 522 pt, plus large que l'écran. Dans `LoadingView.progressBar`, remplacer la dernière ligne :

```swift
        .frame(width: Device.isPhone ? nil : 900.scaled, height: 12.scaled)
        .frame(maxWidth: Device.isPhone ? .infinity : nil)
        .padding(.horizontal, Device.isPhone ? 40.scaled : 0)
```

- [ ] **Étape 2 : marges de `NotEnoughPlacesView`**

`padding(.horizontal, 200.scaled)` laisse 232 pt de marges pour 161 pt de texte utile. En bas du `VStack` du `body` :

```swift
            .padding(.horizontal, (Device.isPhone ? 24 : 200).scaled)
```

- [ ] **Étape 3 : empiler les deux boutons de `NotEnoughPlacesView`**

Extraire les deux boutons en propriétés, à l'identique de ce qu'il y a aujourd'hui dans le `body` :

```swift
    private var helpButton: some View {
        Button("Voir comment faire") {
            withAnimation(Theme.focusAnimation) { showingHelp.toggle() }
        }
        .buttonStyle(SecondaryPillButtonStyle(horizontalPadding: 44, verticalPadding: 18, fontSize: 24))
        .macFocusable()
        .focused($focusedButton, equals: .help)
        .macFocusOnHover($focusedButton, equals: .help)
    }

    private var demoButton: some View {
        Button {
            viewModel.startDemoMode()
        } label: {
            HStack(spacing: 12.scaled) {
                Text("Mode démo")
                Image(systemName: "play.fill")
                    .font(.system(size: 18.scaled))
            }
        }
        .buttonStyle(GradientPillButtonStyle(horizontalPadding: 44, verticalPadding: 18, fontSize: 24))
        .macFocusable()
        .focused($focusedButton, equals: .demo)
        .macFocusOnHover($focusedButton, equals: .demo)
    }
```

puis le conteneur conditionnel :

```swift
    @ViewBuilder
    private var actionButtons: some View {
        if Device.isPhone {
            VStack(spacing: 16.scaled) {
                helpButton
                demoButton
            }
        } else {
            HStack(spacing: 30.scaled) {
                helpButton
                demoButton
            }
        }
    }
```

Le `body` appelle `actionButtons`, en conservant le `.padding(.top, 8.scaled)` et le bloc `#if os(macOS) .macMoveCommand { … } #endif` qui le suivaient.

- [ ] **Étape 4 : marges de `errorView`**

Dans `ContentView.errorView`, dernière ligne du `Text(message)` :

```swift
                .padding(.horizontal, (Device.isPhone ? 24 : 200).scaled)
```

- [ ] **Étape 5 : build et captures**

L'écran de chargement passe vite ; pour le capturer, lancer sans `-demoMode` sur un simulateur dont la photothèque est vide : l'app reste sur `LoadingView` puis bascule sur `NotEnoughPlacesView`, ce qui donne les deux écrans.

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project Wanderback.xcodeproj -scheme Wanderback \
  -destination 'generic/platform=tvOS' -derivedDataPath .build-sim build 2>&1 | tail -1
scripts/shot-ios.sh "iPhone 17" /tmp/t8-vide.png
scripts/shot-ios.sh "iPhone SE (3rd generation)" /tmp/t8-vide-se.png
```

Attendu : la barre de progression tient dans l'écran avec des marges ; le texte de « Pas assez de destinations » occupe la largeur au lieu d'être compressé en colonne étroite ; les deux boutons sont empilés.

Le simulateur demandera l'autorisation d'accès aux photos : la capture montrera peut-être l'alerte système. C'est acceptable pour cette validation.

- [ ] **Étape 6 : commit**

```bash
git add -A
git commit -m "Écrans de chargement, d'erreur et « pas assez de lieux » adaptés à l'iPhone"
```

---

### Tâche 9 : calibrage final et non-régression

Livrable : `Theme.scale` arrêté sur pièce, les trois autres plateformes vérifiées inchangées, documentation à jour.

**Fichiers :**
- Modifier : `Wanderback/DesignSystem/Theme.swift` (valeur de `scale`, si le calibrage l'exige)
- Modifier : `README.md`
- Modifier : `docs/superpowers/specs/2026-09-06-portage-iphone-design.md` (amendements éventuels)

- [ ] **Étape 1 : parcourir les 6 écrans sur les 3 gabarits**

```bash
for sim in "iPhone 17" "iPhone SE (3rd generation)" "iPhone 17 Pro Max"; do
  tag="$(echo "$sim" | tr -d ' ()' )"
  scripts/shot-ios.sh "$sim" "/tmp/final-$tag-accueil.png" -demoMode -noMosaic
  scripts/shot-ios.sh "$sim" "/tmp/final-$tag-jeu.png"     -demoMode -noMosaic -screen game
  scripts/shot-ios.sh "$sim" "/tmp/final-$tag-reveal.png"  -demoMode -noMosaic -screen reveal
  scripts/shot-ios.sh "$sim" "/tmp/final-$tag-resume.png"  -demoMode -noMosaic -screen summary
done
```

Regarder les 12 captures. Ajuster `Theme.scale` (0,58 est une valeur de départ) et, si besoin, les espacements des tâches 4 à 8. Toute valeur retenue qui s'écarte de la spec est reportée dans la spec à l'étape 4.

- [ ] **Étape 2 : non-régression sur l'appareil réel**

Brancher l'iPhone, l'appairer, relever son UDID :

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcrun devicectl list devices
```

L'enregistrer au portail développeur (POST `/v1/devices` de l'API App Store Connect, comme pour « iPad de Bastien » — cf. la mémoire `project-testflight-upload`), puis installer et jouer une vraie partie : c'est la seule validation qui exerce PhotoKit sur une vraie photothèque et le verrou portrait sur un appareil physique.

- [ ] **Étape 3 : non-régression tvOS, macOS, iPad**

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project Wanderback.xcodeproj -scheme Wanderback \
  -destination 'generic/platform=tvOS' -derivedDataPath .build-sim build 2>&1 | tail -1
xcodebuild -project Wanderback.xcodeproj -scheme WanderbackMac \
  -destination 'generic/platform=macOS' -derivedDataPath .build-sim build 2>&1 | tail -1
scripts/shot-ios.sh "iPad Pro 11-inch (M5)" /tmp/final-ipad-jeu.png -demoMode -noMosaic -screen game
```

Comparer la capture iPad à `docs/appstore/tv-2-jeu.png` en composition : rangée de 4 cartes, logo présent dans la barre haute, mêmes proportions. Si quoi que ce soit a bougé sur iPad, c'est qu'une branche `Device.isPhone` a été mal posée.

- [ ] **Étape 4 : documentation**

Dans `README.md` : le sous-titre et la phrase d'introduction mentionnent « Apple TV (tvOS), Mac (macOS) & iPad (iPadOS) » — ajouter l'iPhone. Dans les prérequis, remplacer la ligne iPad par : « ou un iPhone / iPad sous iOS 26+ (cible WanderbackiOS) ». Corriger aussi la mention de la cible `WanderbackPad` partout où elle apparaît.

Amender la spec si le calibrage a changé des valeurs, en suivant la convention du portage iPad : une mention « amendement » à l'endroit concerné plutôt qu'une réécriture silencieuse.

- [ ] **Étape 5 : commit**

```bash
git add -A
git commit -m "Calibrage final de l'échelle iPhone, non-régression des 3 autres plateformes, README"
```

---

### Tâche 10 : build 5 et upload TestFlight

Livrable : un build iPhone disponible sur TestFlight.

**Fichiers :**
- Modifier : `Wanderback.xcodeproj/project.pbxproj` (`CURRENT_PROJECT_VERSION`)

- [ ] **Étape 1 : incrémenter le numéro de build**

La numérotation est partagée entre plateformes : les 6 emplacements (2 configurations × 3 cibles) passent de 4 à 5.

```bash
sed -i '' 's/CURRENT_PROJECT_VERSION = 4;/CURRENT_PROJECT_VERSION = 5;/g' Wanderback.xcodeproj/project.pbxproj
grep -c "CURRENT_PROJECT_VERSION = 5;" Wanderback.xcodeproj/project.pbxproj  # doit afficher 6
```

- [ ] **Étape 2 : archiver**

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
SCRATCH=/tmp/wanderback-ios-build5
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_MABCCJ4S35.p8"

xcodebuild archive \
  -project Wanderback.xcodeproj \
  -scheme WanderbackiOS \
  -destination 'generic/platform=iOS' \
  -archivePath "$SCRATCH/Wanderback.xcarchive" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" \
  -authenticationKeyID MABCCJ4S35 \
  -authenticationKeyIssuerID a6ac781b-dc96-4846-a507-ca104b8d7782
```

Utiliser **impérativement** la clé `MABCCJ4S35` : c'est la seule à disposer de l'accès aux certificats de distribution gérés dans le cloud. L'ancienne clé `P42BG7P56Z` fait échouer l'export sur « Cloud signing permission error ». Les trois flags d'authentification sont obligatoires : le compte Xcode du trousseau est cassé (« missing Xcode-Username ») et sans eux l'archive échoue sur « No Accounts ».

- [ ] **Étape 3 : exporter l'IPA**

```bash
cat > "$SCRATCH/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>XKFAS389Q8</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$SCRATCH/Wanderback.xcarchive" \
  -exportPath "$SCRATCH/export" \
  -exportOptionsPlist "$SCRATCH/ExportOptions.plist" \
  -authenticationKeyPath "$KEY" \
  -authenticationKeyID MABCCJ4S35 \
  -authenticationKeyIssuerID a6ac781b-dc96-4846-a507-ca104b8d7782
```

- [ ] **Étape 4 : téléverser**

```bash
xcrun altool --upload-app \
  -f "$SCRATCH/export/Wanderback.ipa" \
  -t ios \
  --apiKey MABCCJ4S35 \
  --apiIssuer a6ac781b-dc96-4846-a507-ca104b8d7782
```

Attendu : `No errors uploading`. Les erreurs de validation connues sur cette app sont ITMS-90474 (orientations iPad) et ITMS-90717 (canal alpha dans l'icône) ; les deux sont déjà couvertes et ne doivent pas réapparaître.

- [ ] **Étape 5 : commit et PR**

```bash
git add -A
git commit -m "Build 5 : premier upload TestFlight iPhone"
git push -u origin feature/portage-iphone
gh pr create --title "Portage iPhone (cible universelle, portrait)" --body "…"
```

---

## Revue du plan

**Couverture de la spec** — chaque composant de la spec est couvert : réglages de cible et renommage (T1), verrou d'orientation (T2), `Device.isPhone` (T2), `Theme.scale` (T2 puis calibrage T9), les huit blocs de layout (T3–T8), validation (T9), livraison (T10).

**Écart assumé** — la spec ne mentionne pas `SceneBackground`. Son `endRadius: 1400` non mis à l'échelle est le même défaut de classe que la vignette de `RevealView`, découvert en écrivant le plan ; il est corrigé en T2 et la spec est amendée en T9 étape 4.

**Ce que ce plan ne fait pas** — il ne corrige pas la vignette de `RevealView` ni `SceneBackground` en fenêtre macOS réduite, où le même défaut existe : hors périmètre, pour ne pas modifier le rendu macOS dans ce lot. Il ne traite pas non plus l'iPad affiché en portrait (le verrou runtime ne s'applique pas en fenêtrage iPadOS 26), qui reste hors périmètre par la spec.
