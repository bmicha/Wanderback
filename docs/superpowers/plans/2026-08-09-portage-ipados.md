# Portage iPadOS de Wanderback — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre Wanderback jouable nativement sur iPad (tactile, paysage) via une cible `WanderbackPad` séparée partageant les mêmes sources, distribuable sur TestFlight.

**Architecture:** Décalque du portage macOS : le projet utilise un `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), la nouvelle cible référence le même dossier `Wanderback/` et hérite de tous les fichiers, sauf `LaunchScreen.storyboard` (storyboard tvOS, exclu via exception set). Les abstractions `Platform/` existantes sont déjà no-op sur iOS ; le travail spécifique se limite à l'échelle, au retour tactile et au bouton de sortie de partie.

**Tech Stack:** Swift 5 / SwiftUI, PhotoKit, MapKit, SwiftData, CoreLocation. Xcode 27 bêta sur macOS 27 bêta, simulateur iPad iOS 26.

**Spec :** `docs/superpowers/specs/2026-08-09-portage-ipados-design.md`

## Global Constraints

- Branche de travail : `feature/portage-ipados` (déjà créée).
- **Toujours préfixer les commandes `xcodebuild`/`xcrun`/`swift`** : `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` (xcode-select pointe sur les CommandLineTools — cf. mémoire machine).
- Cible iPad : nom `WanderbackPad`, `PRODUCT_NAME = Wanderback`, `PRODUCT_BUNDLE_IDENTIFIER = com.bastien.Wanderback` (même app record App Store Connect que tvOS/macOS), `DEVELOPMENT_TEAM = XKFAS389Q8`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `TARGETED_DEVICE_FAMILY = 2`, `SWIFT_VERSION = 5.0`.
- Identifiants pbxproj de la nouvelle cible (préfixe `AD`, miroir du préfixe `AC` de WanderbackMac) : target `AD0000000000000000000001`, product `AD0000000000000000000002`, Sources `AD0000000000000000000003`, Frameworks `AD0000000000000000000004`, Resources `AD0000000000000000000005`, config list `AD0000000000000000000006`, config Debug `AD0000000000000000000007`, config Release `AD0000000000000000000008`, exception set `AD0000000000000000000009`.
- Les cibles tvOS (`Wanderback`) et macOS (`WanderbackMac`) ne doivent être modifiées par aucune tâche (exception : l'incrément de `CURRENT_PROJECT_VERSION` en tâche 7). Chaque tâche se termine par la vérification des **trois** builds :
  ```bash
  cd "/Users/bastienmicha/Claude Projects/Wanderback"
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
    -project Wanderback.xcodeproj -scheme Wanderback \
    -destination 'generic/platform=tvOS' build CODE_SIGNING_ALLOWED=NO -quiet
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
    -project Wanderback.xcodeproj -scheme WanderbackMac \
    -destination 'platform=macOS' -configuration Debug build \
    SYMROOT=build CODE_SIGNING_ALLOWED=NO -quiet
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
    -project Wanderback.xcodeproj -scheme WanderbackPad \
    -destination 'generic/platform=iOS Simulator' -configuration Debug build \
    SYMROOT=build CODE_SIGNING_ALLOWED=NO -quiet
  ```
  Attendu : `** BUILD SUCCEEDED **` ×3 (la build iPad n'existe qu'à partir de la tâche 1).
- Textes UI en français ; commentaires de code dans le style existant (français, sobres).
- Il n'existe pas de cible de tests unitaires dans ce projet : la « vérification » de chaque tâche est la compilation des trois plateformes + les contrôles visuels de la tâche 6.

---

### Task 1: Cible Xcode `WanderbackPad` (pbxproj, scheme)

**Files:**
- Modify: `Wanderback.xcodeproj/project.pbxproj`
- Create: `Wanderback.xcodeproj/xcshareddata/xcschemes/WanderbackPad.xcscheme`

**Interfaces:**
- Consumes: rien (première tâche) — les abstractions `Platform/` du portage macOS compilent déjà sur iOS.
- Produces: scheme `WanderbackPad` buildable en CLI ; l'app iOS `Wanderback.app` dans `build/Debug-iphonesimulator/`. Identifiants pbxproj listés dans les contraintes globales.

- [ ] **Step 1: Éditer `project.pbxproj` — huit insertions**

**1a.** Dans la section `PBXFileReference`, après la ligne du produit `AC0000000000000000000002` (ligne 11) :

```
		AD0000000000000000000002 /* Wanderback.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Wanderback.app; sourceTree = BUILT_PRODUCTS_DIR; };
```

**1b.** Dans la section `PBXFileSystemSynchronizedBuildFileExceptionSet`, après le bloc `AC0000000000000000000009` — exclut le storyboard tvOS de la cible iPad :

```
		AD0000000000000000000009 /* Exceptions for "Wanderback" folder in "WanderbackPad" target */ = {
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				LaunchScreen.storyboard,
			);
			target = AD0000000000000000000001 /* WanderbackPad */;
		};
```

**1c.** Dans le `PBXFileSystemSynchronizedRootGroup` (`3F0A46732F65D3A100A3FD2D`), ajouter à la liste `exceptions` existante :

```
				AD0000000000000000000009 /* Exceptions for "Wanderback" folder in "WanderbackPad" target */,
```

**1d.** Dans les sections build phases, ajouter les trois phases de la nouvelle cible, à côté de leurs homologues `AC…` (mêmes structures vides) :

```
		AD0000000000000000000003 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```
```
		AD0000000000000000000004 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```
```
		AD0000000000000000000005 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

**1e.** Nouvelle entrée dans `PBXNativeTarget`, après le bloc `AC0000000000000000000001` :

```
		AD0000000000000000000001 /* WanderbackPad */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AD0000000000000000000006 /* Build configuration list for PBXNativeTarget "WanderbackPad" */;
			buildPhases = (
				AD0000000000000000000003 /* Sources */,
				AD0000000000000000000004 /* Frameworks */,
				AD0000000000000000000005 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				3F0A46732F65D3A100A3FD2D /* Wanderback */,
			);
			name = WanderbackPad;
			packageProductDependencies = (
			);
			productName = WanderbackPad;
			productReference = AD0000000000000000000002 /* Wanderback.app */;
			productType = "com.apple.product-type.application";
		};
```

**1f.** Dans `PBXProject` :
- `TargetAttributes` : ajouter après le bloc `AC0000000000000000000001` :
```
					AD0000000000000000000001 = {
						CreatedOnToolsVersion = 26.3;
						ProvisioningStyle = Automatic;
					};
```
- Liste `targets` : ajouter `AD0000000000000000000001 /* WanderbackPad */,` après la ligne WanderbackMac.
- Groupe `Products` (`3F0A46722F65D3A100A3FD2D`) : ajouter `AD0000000000000000000002 /* Wanderback.app */,` aux `children`.

**1g.** Dans `XCBuildConfiguration`, ajouter les deux configs de la cible après le bloc `AC0000000000000000000008`. Ne PAS mettre `ASSETCATALOG_COMPILER_APPICON_NAME` maintenant (l'appiconset iOS n'existe qu'en tâche 2, sinon la build échoue) :

```
		AD0000000000000000000007 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_IDENTITY = "Apple Development";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 3;
				DEVELOPMENT_TEAM = XKFAS389Q8;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.family-games";
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "Wanderback utilise vos photos pour créer un jeu de devinettes basé sur les lieux où elles ont été prises.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.bastien.Wanderback;
				PRODUCT_NAME = Wanderback;
				PROVISIONING_PROFILE_SPECIFIER = "";
				SDKROOT = iphoneos;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 2;
			};
			name = Debug;
		};
		AD0000000000000000000008 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_IDENTITY = "Apple Development";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 3;
				DEVELOPMENT_TEAM = XKFAS389Q8;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.family-games";
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "Wanderback utilise vos photos pour créer un jeu de devinettes basé sur les lieux où elles ont été prises.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.bastien.Wanderback;
				PRODUCT_NAME = Wanderback;
				PROVISIONING_PROFILE_SPECIFIER = "";
				SDKROOT = iphoneos;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 2;
			};
			name = Release;
		};
```

(Différences avec les configs Mac : `SDKROOT = iphoneos`, `IPHONEOS_DEPLOYMENT_TARGET` au lieu de `MACOSX_DEPLOYMENT_TARGET`, `TARGETED_DEVICE_FAMILY = 2`, les 4 clés `INFOPLIST_KEY_UI*` — orientations paysage seules, launch screen généré —, `LD_RUNPATH_SEARCH_PATHS` sans `../`, et **pas** de `CODE_SIGN_ENTITLEMENTS` / `ENABLE_HARDENED_RUNTIME` / `COMBINE_HIDPI_IMAGES` — pas de sandbox sur iOS. Pas de `UIRequiresFullScreen` : fenêtrage libre iPadOS 26.)

**1h.** Dans `XCConfigurationList`, ajouter après le bloc `AC0000000000000000000006` :

```
		AD0000000000000000000006 /* Build configuration list for PBXNativeTarget "WanderbackPad" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AD0000000000000000000007 /* Debug */,
				AD0000000000000000000008 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
```

- [ ] **Step 2: Créer le scheme partagé `Wanderback.xcodeproj/xcshareddata/xcschemes/WanderbackPad.xcscheme`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2700" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary"
               BlueprintIdentifier = "AD0000000000000000000001"
               BuildableName = "Wanderback.app"
               BlueprintName = "WanderbackPad"
               ReferencedContainer = "container:Wanderback.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES"/>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary"
            BlueprintIdentifier = "AD0000000000000000000001"
            BuildableName = "Wanderback.app"
            BlueprintName = "WanderbackPad"
            ReferencedContainer = "container:Wanderback.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES"/>
   <AnalyzeAction buildConfiguration = "Debug"/>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
```

- [ ] **Step 3: Vérifier que le projet reste lisible et que les trois cibles buildent**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project Wanderback.xcodeproj -list
```
Attendu : `Targets: Wanderback, WanderbackMac, WanderbackPad` et les 3 schemes.

Puis les trois builds des contraintes globales. Attendu : `** BUILD SUCCEEDED **` ×3. En cas d'erreur de compilation Swift sur la build iPad (API indisponible sur iOS), corriger au cas par cas avec `#if os(iOS)` — aucune n'est attendue : `focusSection` est disponible sur iOS (vérifié dans le swiftinterface du SDK), `onExitCommand` existe sur iOS (jamais délivré), `PlatformImage = UIImage`, MapKit/SwiftData identiques.

- [ ] **Step 4: Commit**

```bash
git add Wanderback.xcodeproj
git commit -m "Ajoute la cible iPad WanderbackPad (sources partagées, paysage seul)"
```

---

### Task 2: Icône iOS (composite carré opaque)

**Files:**
- Create: `scripts/generate-ios-icon.swift`
- Create: `Wanderback/Assets.xcassets/AppIcon-iOS.appiconset/Contents.json` (+ `icon_1024.png` généré)
- Modify: `Wanderback.xcodeproj/project.pbxproj` (configs `AD0000000000000000000007` et `AD0000000000000000000008`)

**Interfaces:**
- Consumes: cible `WanderbackPad` (tâche 1).
- Produces: appiconset `AppIcon-iOS` compilé dans l'app iPad.

**Attention :** ne PAS réutiliser les PNG de `AppIcon.appiconset` (icône Mac) : ils ont des coins arrondis et un canal alpha, interdits sur iOS (le système applique son propre masque ; un canal alpha provoque le rejet ITMS-90717 à l'upload). On régénère un composite **carré, sans transparence** depuis les mêmes couches parallax.

- [ ] **Step 1: Écrire `scripts/generate-ios-icon.swift`**

Même principe que `generate-mac-icon.swift` (couches aspect-fill au même facteur d'échelle), mais : une seule taille 1024, pas de clip arrondi, bitmap RGB sans alpha.

```swift
import AppKit

let assets = URL(fileURLWithPath: "Wanderback/Assets.xcassets")
let stack = assets.appendingPathComponent(
    "App Icon & Top Shelf Image.brandassets/App Icon - App Store.imagestack")
let layerPaths = [
    "Back.imagestacklayer/Content.imageset/back.png",
    "Middle.imagestacklayer/Content.imageset/middle.png",
    "Front.imagestacklayer/Content.imageset/front.png",
]
let layers = layerPaths.map { path -> NSImage in
    guard let image = NSImage(contentsOf: stack.appendingPathComponent(path)) else {
        fatalError("Couche introuvable : \(path)")
    }
    return image
}

let out = assets.appendingPathComponent("AppIcon-iOS.appiconset")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// iOS applique son propre masque d'angles : le composite doit être carré et
// sans canal alpha (ITMS-90717 sinon).
let side: CGFloat = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
    bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: side, height: side)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
for layer in layers {
    let scale = max(side / layer.size.width, side / layer.size.height)
    let w = layer.size.width * scale
    let h = layer.size.height * scale
    layer.draw(in: NSRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h),
               from: .zero, operation: .sourceOver, fraction: 1)
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!
    .write(to: out.appendingPathComponent("icon_1024.png"))
print("✓ icon_1024.png (1024px, sans alpha)")
```

- [ ] **Step 2: Créer `Wanderback/Assets.xcassets/AppIcon-iOS.appiconset/Contents.json`**

```json
{
  "images" : [
    {
      "filename" : "icon_1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 3: Générer le PNG et le contrôler**

```bash
cd "/Users/bastienmicha/Claude Projects/Wanderback"
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift scripts/generate-ios-icon.swift
```
Attendu : `✓ icon_1024.png (1024px, sans alpha)`. Ouvrir le PNG (outil Read) : composition lisible, coins **carrés**, pas de bord transparent. Vérifier l'absence d'alpha :
```bash
sips -g hasAlpha Wanderback/Assets.xcassets/AppIcon-iOS.appiconset/icon_1024.png
```
Attendu : `hasAlpha: no`.

- [ ] **Step 4: Référencer l'icône dans la cible iPad**

Dans `project.pbxproj`, ajouter dans les `buildSettings` des deux configs `AD0000000000000000000007` et `AD0000000000000000000008` (ordre alphabétique, avant `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`) :

```
				ASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-iOS";
```

- [ ] **Step 5: Vérifier**

Les trois builds des contraintes globales : `** BUILD SUCCEEDED **` ×3, puis :
```bash
ls build/Debug-iphonesimulator/Wanderback.app/ | grep -i appicon
```
Attendu : au moins un fichier `AppIcon-iOS…png` (actool copie l'icône dans le bundle iOS). Les builds tvOS et Mac ignorent l'appiconset plateforme `ios`.

- [ ] **Step 6: Commit**

```bash
git add scripts/generate-ios-icon.swift "Wanderback/Assets.xcassets/AppIcon-iOS.appiconset" Wanderback.xcodeproj/project.pbxproj
git commit -m "Icône iOS : composite carré opaque depuis les couches parallax"
```

---

### Task 3: Échelle d'interface iPad (`Theme.scale` = 0,7)

**Files:**
- Modify: `Wanderback/DesignSystem/Theme.swift:63-71`

**Interfaces:**
- Consumes: `Theme.scale` et les helpers `.scaled` existants (portage macOS) — déjà appliqués partout dans les vues.
- Produces: `Theme.scale = 0.7` sur iOS ; tvOS (1.0) et macOS (0.62) inchangés.

- [ ] **Step 1: Ajouter la branche iOS dans `Theme.swift`**

Remplacer le bloc existant :

```swift
    /// L'UI est calibrée pour un canvas TV 1920×1080 regardé à 3 m ; en fenêtre
    /// Mac (~1280 pt) typo et espacements sont réduits d'un facteur global.
    #if os(macOS)
    static let scale: CGFloat = 0.62
    #else
    static let scale: CGFloat = 1.0
    #endif
```

par :

```swift
    /// L'UI est calibrée pour un canvas TV 1920×1080 regardé à 3 m ; en fenêtre
    /// Mac (~1280 pt) et sur iPad (~1200-1400 pt) typo et espacements sont
    /// réduits d'un facteur global.
    #if os(macOS)
    static let scale: CGFloat = 0.62
    #elseif os(iOS)
    static let scale: CGFloat = 0.7
    #else
    static let scale: CGFloat = 1.0
    #endif
```

- [ ] **Step 2: Vérifier les trois builds** (contraintes globales) — attendu : `** BUILD SUCCEEDED **` ×3. Sur tvOS et macOS, valeurs inchangées : rendu strictement identique.

- [ ] **Step 3: Commit**

```bash
git add Wanderback/DesignSystem/Theme.swift
git commit -m "Échelle d'interface iPad : UI TV réduite à 70 %"
```

---

### Task 4: Retour visuel à l'appui (tactile) sur les 5 styles de boutons

**Files:**
- Modify: `Wanderback/DesignSystem/Theme.swift` (GradientPillLabel, SecondaryPillLabel)
- Modify: `Wanderback/Views/AnswerOptionsView.swift` (AnswerCardLabel)
- Modify: `Wanderback/Views/HomeView.swift` (ModeTileLabel, RoundCircleLabel)

**Interfaces:**
- Consumes: les 5 labels de styles du portage macOS (motif `isFocused || isHovered` → `isHighlighted`).
- Produces: chaque label intègre `configuration.isPressed` dans sa surbrillance — au toucher iPad, le visuel « focus » s'applique pendant l'appui. La spec ne citait que 3 styles ; `ModeTileLabel` et `RoundCircleLabel` (accueil) suivent le même motif et sont traités aussi, sinon l'accueil resterait sans retour tactile.

- [ ] **Step 1: Étendre `isHighlighted` dans les 4 labels au motif uniforme**

Dans `GradientPillLabel`, `SecondaryPillLabel` (Theme.swift), `AnswerCardLabel` (AnswerOptionsView.swift) et `ModeTileLabel` (HomeView.swift), remplacer :

```swift
        private var isHighlighted: Bool { isFocused || isHovered }
```

par :

```swift
        private var isHighlighted: Bool { isFocused || isHovered || configuration.isPressed }
```

Rien d'autre à changer dans ces 4 labels : tous les visuels lisent `isHighlighted`, et leurs `.animation(…, value: isHighlighted)` couvrent l'appui. Sur tvOS/macOS, `isPressed` ne s'active qu'au clic/validation, pendant que la surbrillance focus/survol est déjà affichée — aucun changement visible, pas de `#if` nécessaire.

- [ ] **Step 2: `RoundCircleLabel` (HomeView.swift), qui n'a pas de propriété `isHighlighted`**

Dans son `body`, remplacer les trois lectures composées et compléter l'animation :
- `let highlighted = isSelected || isFocused || isHovered` → `let highlighted = isSelected || isFocused || isHovered || configuration.isPressed`
- `.shadow(color: (isFocused || isHovered) ? …)` → `.shadow(color: (isFocused || isHovered || configuration.isPressed) ? …)`
- `.scaleEffect((isFocused || isHovered) ? 1.1 : 1.0)` → `.scaleEffect((isFocused || isHovered || configuration.isPressed) ? 1.1 : 1.0)`
- Après la ligne `.animation(Theme.focusAnimation, value: isHovered)`, ajouter : `.animation(Theme.focusAnimation, value: configuration.isPressed)`

- [ ] **Step 3: Vérifier les trois builds** (contraintes globales) — attendu : `** BUILD SUCCEEDED **` ×3.

- [ ] **Step 4: Commit**

```bash
git add Wanderback/DesignSystem/Theme.swift Wanderback/Views/AnswerOptionsView.swift Wanderback/Views/HomeView.swift
git commit -m "Retour visuel à l'appui : isPressed rejoint le motif focus/survol"
```

---

### Task 5: Bouton « fermer » iOS et message Photos iPad

**Files:**
- Modify: `Wanderback/Views/ContentView.swift` (gameFlow, lignes 46-69)
- Modify: `Wanderback/ViewModels/PhotoLibraryViewModel.swift` (message d'erreur Photos, bloc `#if os(macOS)` / `#else` vers la ligne 125)

**Interfaces:**
- Consumes: `gameViewModel.quit()` (chemin de sortie existant, partagé avec `onExitCommand` tvOS et `macCancelShortcut` macOS).
- Produces: sur iOS uniquement, une croix en haut à gauche des trois écrans du flux de jeu qui ramène à l'accueil ; message d'accès Photos avec le libellé Réglages iOS exact.

- [ ] **Step 1: Ajouter le bouton fermer en overlay de `gameFlow` dans `ContentView.swift`**

Un seul point d'implantation pour les trois écrans (GameView, RevealView, SummaryView) : l'overlay du `Group`. Après le modificateur `.macCancelShortcut { … }` :

```swift
        .macCancelShortcut {
            gameViewModel.quit()
        }
        #if os(iOS)
        // Ni bouton Menu ni touche Échap sur iPad : croix discrète pour quitter la partie.
        .overlay(alignment: .topLeading) {
            Button {
                gameViewModel.quit()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20.scaled, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(16.scaled)
                    .background(Theme.answerSurface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.answerBorder, lineWidth: 1))
            }
            .padding(24.scaled)
        }
        #endif
```

- [ ] **Step 2: Message Photos avec le libellé Réglages iOS**

Dans `PhotoLibraryViewModel.swift`, le bloc plateforme du message d'erreur devient (la branche `#else` actuelle sert tvOS ET iOS ; iOS a droit au chemin Réglages exact) :

```swift
            #if os(macOS)
            errorMessage = "Wanderback a besoin d'accéder à vos photos pour fonctionner. Autorisez l'accès dans Réglages Système > Confidentialité et sécurité > Photos."
            #elseif os(iOS)
            errorMessage = "Wanderback a besoin d'accéder à vos photos pour fonctionner. Autorisez l'accès dans Réglages > Confidentialité et sécurité > Photos."
            #else
            errorMessage = "Wanderback a besoin d'accéder à vos photos pour fonctionner. Autorisez l'accès dans Réglages > Confidentialité > Photos."
            #endif
```

- [ ] **Step 3: Vérifier les trois builds** (contraintes globales) — attendu : `** BUILD SUCCEEDED **` ×3 (le bouton n'est compilé que sur iOS).

- [ ] **Step 4: Commit**

```bash
git add Wanderback/Views/ContentView.swift Wanderback/ViewModels/PhotoLibraryViewModel.swift
git commit -m "Bouton fermer iPad pour quitter la partie, message Photos iOS"
```

---

### Task 6: Vérification visuelle sur simulateur iPad + README

**Files:**
- Modify: `README.md` (mention plateformes)
- Aucun autre fichier attendu — tâche de vérification ; corriger ce qui est découvert (typiquement `Theme.scale` ±0,05).

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces: app validée visuellement écran par écran sur deux gabarits iPad ; README à jour.

- [ ] **Step 1: Démarrer un simulateur iPad grand format**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun simctl list devices available | grep -i ipad
```
Choisir le gabarit « iPad Pro 13-inch » le plus récent listé (le nom exact dépend du SDK bêta), puis :
```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun simctl boot "<nom exact du device>"
```
(Si déjà booté, l'erreur « Unable to boot device in current state: Booted » est bénigne.)

- [ ] **Step 2: Builder, installer et lancer en mode démo**

```bash
cd "/Users/bastienmicha/Claude Projects/Wanderback"
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project Wanderback.xcodeproj -scheme WanderbackPad \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  SYMROOT=build -quiet
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun simctl install booted build/Debug-iphonesimulator/Wanderback.app
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun simctl launch booted com.bastien.Wanderback -demoMode -noMosaic
```
(`-demoMode` évite le prompt Photos, comme pour les captures Mac.)

- [ ] **Step 3: Capturer et inspecter chaque écran**

Pour chaque écran — accueil (sans `-screen`), puis `-screen game`, `-screen reveal`, `-screen summary` (relancer avec `xcrun simctl launch booted com.bastien.Wanderback -demoMode -noMosaic -screen <écran>` après `xcrun simctl terminate booted com.bastien.Wanderback`) — attendre ~5 s puis :

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun simctl io booted screenshot \
  /private/tmp/claude-501/-Users-bastienmicha-Claude-Projects-Wanderback/618e1393-daf8-4dbf-9522-3feebf574078/scratchpad/ipad13-<écran>.png
```

Lire chaque capture (outil Read) et vérifier : app en **paysage** (orientations verrouillées), rien de tronqué ni de disproportionné, textes lisibles, cartes MapKit affichées, croix « fermer » visible en haut à gauche des écrans de jeu et n'entrant en collision avec rien. Ajuster `Theme.scale` iOS (±0,05) ou un padding précis si un écran déborde, rebuilder, recapturer.

- [ ] **Step 4: Répéter sur un gabarit 11″**

Booter le device « iPad Pro 11-inch » (ou « iPad Air 11-inch ») le plus récent listé, refaire steps 2-3 avec des captures `ipad11-<écran>.png`. C'est le gabarit le plus contraint (~1210×834 pt) : c'est lui qui décide si `Theme.scale = 0.7` tient.

- [ ] **Step 5: Test tactile de bout en bout (interaction utilisateur si simulateur ouvert)**

Ouvrir l'app Simulator pour un test manuel : partie complète en mode démo (tap sur les cartes réponse — vérifier le retour visuel à l'appui —, « Round suivant », croix pour quitter). Si l'interaction manuelle n'est pas possible dans la session, le noter et reporter ce contrôle au test TestFlight sur iPad physique (tâche 7).

- [ ] **Step 6: Mettre à jour `README.md`**

- Ligne 3 : `> Jeu de reconnaissance de lieux à partir de tes photos de vacances · Apple TV (tvOS), Mac (macOS) & iPad (iPadOS)`
- Ligne 5 : remplacer « est une application tvOS et macOS » par « est une application tvOS, macOS et iPadOS ».
- Section Prérequis, ajouter : `- ou un iPad sous iPadOS 26+ (cible WanderbackPad)`.

- [ ] **Step 7: Vérifier les trois builds une dernière fois, puis commit**

```bash
git add README.md
git commit -m "Valide le portage iPad et documente la plateforme dans le README"
```
(Si des ajustements de code ont été faits aux steps 3-5, les inclure dans ce commit avec un message adapté.)

---

### Task 7: Archive et upload TestFlight iOS

**Files:**
- Modify: `Wanderback.xcodeproj/project.pbxproj` (`CURRENT_PROJECT_VERSION`, 6 emplacements : 2 configs tvOS + 2 Mac + 2 iPad)
- Create (scratchpad, non versionné) : `ExportOptionsPad.plist`

**Interfaces:**
- Consumes: app validée (tâche 6) ; clé API ASC `~/.appstoreconnect/private_keys/AuthKey_P42BG7P56Z.p8`.
- Produces: build iOS visible dans TestFlight.

**Préalable utilisateur (bloquant) :** le record App Store Connect `com.bastien.Wanderback` couvre tvOS et macOS ; l'utilisateur doit ajouter la plateforme **iOS** à l'app dans App Store Connect (apps > Wanderback > + plateforme) avant l'upload. Demander confirmation explicite avant d'uploader (action externe).

**Risque identifié :** la combinaison « paysage seul sans `UIRequiresFullScreen` » a historiquement déclenché l'erreur de validation ITMS-90474 (le multitâche iPad exigeait les 4 orientations). Les SDK récents ont assoupli la règle avec le fenêtrage iPadOS 26, mais si l'upload est rejeté avec ce code : **s'arrêter et demander à l'utilisateur** de trancher entre (a) ajouter les orientations portrait (layouts à revalider) et (b) poser `UIRequiresFullScreen = YES` (renonce au fenêtrage libre, choix de spec à amender).

- [ ] **Step 1: Incrémenter le build number**

Dans `project.pbxproj`, passer `CURRENT_PROJECT_VERSION = 3;` à `4` dans les **6** configs — chaque upload exige un numéro unique et les plateformes du même app record partagent la numérotation.

- [ ] **Step 2: Archiver**

```bash
cd "/Users/bastienmicha/Claude Projects/Wanderback"
SCRATCH=/private/tmp/claude-501/-Users-bastienmicha-Claude-Projects-Wanderback/618e1393-daf8-4dbf-9522-3feebf574078/scratchpad
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild archive \
  -project Wanderback.xcodeproj -scheme WanderbackPad \
  -destination 'generic/platform=iOS' \
  -archivePath "$SCRATCH/WanderbackPad.xcarchive" -allowProvisioningUpdates
```
Attendu : `** ARCHIVE SUCCEEDED **`.

- [ ] **Step 3: Exporter**

`$SCRATCH/ExportOptionsPad.plist` :
```xml
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
```
```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -exportArchive \
  -archivePath "$SCRATCH/WanderbackPad.xcarchive" \
  -exportOptionsPlist "$SCRATCH/ExportOptionsPad.plist" \
  -exportPath "$SCRATCH/export-pad" -allowProvisioningUpdates
```
Attendu : `** EXPORT SUCCEEDED **` et un `Wanderback.ipa` dans `export-pad/`.

- [ ] **Step 4: Uploader (après confirmation utilisateur)**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun altool --upload-app \
  -f "$SCRATCH/export-pad/Wanderback.ipa" -t ios \
  --apiKey P42BG7P56Z --apiIssuer a6ac781b-dc96-4846-a507-ca104b8d7782
```
Attendu : `No errors uploading`. (Rappel mémoire : les builds SDK bêta passent sur TestFlight mais pas en release App Store. Voir aussi le risque ITMS-90474 ci-dessus.)

- [ ] **Step 5: Commit**

```bash
git add Wanderback.xcodeproj/project.pbxproj
git commit -m "Build 4 : premier upload TestFlight iPad"
```
