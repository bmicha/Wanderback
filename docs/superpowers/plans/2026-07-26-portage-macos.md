# Portage macOS de Wanderback — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre Wanderback (app tvOS SwiftUI) jouable nativement sur macOS via une cible `WanderbackMac` séparée partageant les mêmes sources, avec fenêtre, souris et clavier, distribuable sur TestFlight.

**Architecture:** Le projet utilise un `PBXFileSystemSynchronizedRootGroup` (Xcode 16+) : la nouvelle cible référence le même dossier `Wanderback/` et hérite automatiquement de tous les fichiers, à l'exception de `LaunchScreen.storyboard` (storyboard tvOS, exclu via exception set). Les divergences de code passent par `#if os(macOS)` et un typealias `PlatformImage`.

**Tech Stack:** Swift 5 / SwiftUI, PhotoKit, MapKit, SwiftData, CoreLocation. Xcode 27 bêta sur macOS 27 bêta.

**Spec :** `docs/superpowers/specs/2026-07-26-portage-macos-design.md`

## Global Constraints

- Branche de travail : `feature/portage-macos` (déjà créée).
- **Toujours préfixer les commandes `xcodebuild`/`xcrun`** : `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` (xcode-select pointe sur les CommandLineTools — cf. mémoire machine).
- Ne pas lancer d'app avec `open -a` (échoue sur macOS 27 bêta, erreur -10664) : exécuter le binaire du bundle directement.
- Cible Mac : nom `WanderbackMac`, `PRODUCT_NAME = Wanderback`, `PRODUCT_BUNDLE_IDENTIFIER = com.bastien.Wanderback` (même app record App Store Connect que tvOS), `DEVELOPMENT_TEAM = XKFAS389Q8`, `MACOSX_DEPLOYMENT_TARGET = 26.0`, `SWIFT_VERSION = 5.0`.
- La cible tvOS existante (`Wanderback`, tvOS 26.2) ne doit être modifiée par aucune tâche ; chaque tâche se termine par une vérification que la build tvOS passe encore :
  ```bash
  cd "/Users/bastienmicha/Claude Projects/Wanderback"
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
    -project Wanderback.xcodeproj -scheme Wanderback \
    -destination 'generic/platform=tvOS' build CODE_SIGNING_ALLOWED=NO -quiet
  ```
  Attendu : `** BUILD SUCCEEDED **`.
- Build Mac de référence (disponible à partir de la tâche 2) :
  ```bash
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
    -project Wanderback.xcodeproj -scheme WanderbackMac \
    -destination 'platform=macOS' -configuration Debug build \
    SYMROOT=build CODE_SIGNING_ALLOWED=NO -quiet
  ```
  Attendu : `** BUILD SUCCEEDED **`.
- Textes UI en français ; commentaires de code dans le style existant (français, sobres).
- Il n'existe pas de cible de tests unitaires dans ce projet : la « vérification » de chaque tâche est la compilation des deux plateformes + les contrôles manuels de la tâche 8.

---

### Task 1: Abstraction `PlatformImage` (UIImage ↔ NSImage)

**Files:**
- Create: `Wanderback/Platform/PlatformImage.swift`
- Modify: `Wanderback/Services/PhotoImageLoader.swift`
- Modify: `Wanderback/Views/GameView.swift`
- Modify: `Wanderback/Views/HomeView.swift`
- Modify: `Wanderback/Views/RevealView.swift`

**Interfaces:**
- Consumes: rien (première tâche).
- Produces: `typealias PlatformImage` (= `UIImage` sur tvOS, `NSImage` sur macOS) et `Image.init(platformImage: PlatformImage)`. Toutes les signatures de `PhotoImageLoader` passent de `UIImage` à `PlatformImage` : `loadImage(assetIdentifier:targetSize:) async -> PlatformImage?` et `loadRandomImages(from:count:targetSize:) async -> [PlatformImage]`.

- [ ] **Step 1: Créer `Wanderback/Platform/PlatformImage.swift`**

```swift
import SwiftUI

#if os(macOS)
import AppKit
/// Type d'image natif de la plateforme (NSImage sur macOS, UIImage ailleurs).
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

extension Image {
    /// Construit une Image SwiftUI depuis le type d'image natif de la plateforme.
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
```

- [ ] **Step 2: Adapter `PhotoImageLoader.swift`**

Supprimer la ligne `import UIKit` (ligne 3) et remplacer les 4 occurrences de `UIImage` par `PlatformImage` :
- ligne 16 : `func loadImage(assetIdentifier: String, targetSize: CGSize) async -> PlatformImage?`
- ligne 24 : `... async -> [PlatformImage]`
- ligne 26 : `var images: [PlatformImage] = []`
- ligne 35 : `private func requestImage(for asset: PHAsset, targetSize: CGSize) async -> PlatformImage?`

(Sur macOS, le callback de `PHCachingImageManager.requestImage` fournit déjà un `NSImage` — aucune autre adaptation.)

- [ ] **Step 3: Adapter les 3 vues**

- `GameView.swift` ligne 6 : `@State private var roundImage: PlatformImage?` ; lignes 37 et 46 : `Image(platformImage: roundImage)`.
- `HomeView.swift` ligne 9 : `@State private var mosaicImages: [PlatformImage] = []` ; ligne 83 : `Image(platformImage: mosaicImages[index])`.
- `RevealView.swift` ligne 9 : `@State private var sameDayImages: [PlatformImage] = []` ; ligne 205 : `Image(platformImage: image)` ; ligne 232 : `var images: [PlatformImage] = []`.

- [ ] **Step 4: Vérifier la build tvOS**

Commande de build tvOS des contraintes globales. Attendu : `** BUILD SUCCEEDED **` (comportement inchangé, `PlatformImage == UIImage` sur tvOS).

- [ ] **Step 5: Commit**

```bash
git add Wanderback/Platform/PlatformImage.swift Wanderback/Services/PhotoImageLoader.swift Wanderback/Views/GameView.swift Wanderback/Views/HomeView.swift Wanderback/Views/RevealView.swift
git commit -m "Abstrait UIImage derrière PlatformImage pour le portage macOS"
```

---

### Task 2: Cible Xcode `WanderbackMac` (pbxproj, entitlements, scheme)

**Files:**
- Create: `Wanderback/WanderbackMac.entitlements`
- Create: `Wanderback.xcodeproj/xcshareddata/xcschemes/WanderbackMac.xcscheme`
- Modify: `Wanderback.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `PlatformImage` (tâche 1) — sans elle, la compilation macOS échoue sur `import UIKit`.
- Produces: scheme `WanderbackMac` buildable en CLI ; l'app `Wanderback.app` macOS dans `build/Debug/`. Identifiants pbxproj de la cible : target `AC0000000000000000000001`, product `AC0000000000000000000002`, config list `AC0000000000000000000006`, configs Debug `AC0000000000000000000007` / Release `AC0000000000000000000008`.

- [ ] **Step 1: Créer `Wanderback/WanderbackMac.entitlements`**

Sandbox obligatoire pour TestFlight ; `network.client` indispensable (géocodage CLGeocoder, tuiles MapKit, téléchargement iCloud des photos — ajout par rapport à la spec, sinon tout accès réseau est bloqué par le sandbox).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.personal-information.photos-library</key>
	<true/>
</dict>
</plist>
```

- [ ] **Step 2: Éditer `project.pbxproj`**

Sept insertions, toutes dans `Wanderback.xcodeproj/project.pbxproj` :

**2a.** Dans la section `PBXFileReference`, après la ligne du produit existant (ligne 10) :

```
		AC0000000000000000000002 /* Wanderback.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Wanderback.app; sourceTree = BUILT_PRODUCTS_DIR; };
```

**2b.** Nouvelle section après `/* End PBXFileSystemSynchronizedRootGroup section */` — exclut le storyboard tvOS de la cible Mac :

```
/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
		AC0000000000000000000009 /* Exceptions for "Wanderback" folder in "WanderbackMac" target */ = {
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				LaunchScreen.storyboard,
			);
			target = AC0000000000000000000001 /* WanderbackMac */;
		};
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */
```

**2c.** Dans le `PBXFileSystemSynchronizedRootGroup` existant (`3F0A46732F65D3A100A3FD2D`), ajouter la propriété `exceptions` :

```
		3F0A46732F65D3A100A3FD2D /* Wanderback */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			exceptions = (
				AC0000000000000000000009 /* Exceptions for "Wanderback" folder in "WanderbackMac" target */,
			);
			path = Wanderback;
			sourceTree = "<group>";
		};
```

**2d.** Dans les sections build phases, ajouter les trois phases de la nouvelle cible (mêmes structures vides que celles de la cible tvOS) : `AC0000000000000000000003` (`PBXSourcesBuildPhase`), `AC0000000000000000000004` (`PBXFrameworksBuildPhase`), `AC0000000000000000000005` (`PBXResourcesBuildPhase`).

**2e.** Nouvelle entrée dans `PBXNativeTarget` :

```
		AC0000000000000000000001 /* WanderbackMac */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AC0000000000000000000006 /* Build configuration list for PBXNativeTarget "WanderbackMac" */;
			buildPhases = (
				AC0000000000000000000003 /* Sources */,
				AC0000000000000000000004 /* Frameworks */,
				AC0000000000000000000005 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				3F0A46732F65D3A100A3FD2D /* Wanderback */,
			);
			name = WanderbackMac;
			packageProductDependencies = (
			);
			productName = WanderbackMac;
			productReference = AC0000000000000000000002 /* Wanderback.app */;
			productType = "com.apple.product-type.application";
		};
```

**2f.** Dans `PBXProject`, ajouter `AC0000000000000000000001 /* WanderbackMac */,` à la liste `targets` ; dans le groupe `Products` (`3F0A46722F65D3A100A3FD2D`), ajouter `AC0000000000000000000002 /* Wanderback.app */,` aux `children`.

**2g.** Dans `XCBuildConfiguration`, ajouter les deux configs de la cible (l'icône `AppIcon` sera référencée en tâche 3 ; ne pas mettre `ASSETCATALOG_COMPILER_APPICON_NAME` maintenant, sinon la build échoue tant que l'appiconset n'existe pas) :

```
		AC0000000000000000000007 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = Wanderback/WanderbackMac.entitlements;
				CODE_SIGN_IDENTITY = "Apple Development";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 2;
				DEVELOPMENT_TEAM = XKFAS389Q8;
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.family-games";
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "Wanderback utilise vos photos pour créer un jeu de devinettes basé sur les lieux où elles ont été prises.";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 26.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.bastien.Wanderback;
				PRODUCT_NAME = Wanderback;
				PROVISIONING_PROFILE_SPECIFIER = "";
				SDKROOT = macosx;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		AC0000000000000000000008 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = Wanderback/WanderbackMac.entitlements;
				CODE_SIGN_IDENTITY = "Apple Development";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 2;
				DEVELOPMENT_TEAM = XKFAS389Q8;
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.family-games";
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "Wanderback utilise vos photos pour créer un jeu de devinettes basé sur les lieux où elles ont été prises.";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 26.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.bastien.Wanderback;
				PRODUCT_NAME = Wanderback;
				PROVISIONING_PROFILE_SPECIFIER = "";
				SDKROOT = macosx;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
```

(Les deux configs sont identiques — les différences Debug/Release génériques (optimisation, dSYM…) viennent des configs projet héritées.)

**2h.** Dans `XCConfigurationList`, ajouter :

```
		AC0000000000000000000006 /* Build configuration list for PBXNativeTarget "WanderbackMac" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AC0000000000000000000007 /* Debug */,
				AC0000000000000000000008 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
```

- [ ] **Step 3: Créer le scheme partagé `Wanderback.xcodeproj/xcshareddata/xcschemes/WanderbackMac.xcscheme`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2700" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary"
               BlueprintIdentifier = "AC0000000000000000000001"
               BuildableName = "Wanderback.app"
               BlueprintName = "WanderbackMac"
               ReferencedContainer = "container:Wanderback.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES"/>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary"
            BlueprintIdentifier = "AC0000000000000000000001"
            BuildableName = "Wanderback.app"
            BlueprintName = "WanderbackMac"
            ReferencedContainer = "container:Wanderback.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES"/>
   <AnalyzeAction buildConfiguration = "Debug"/>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
```

- [ ] **Step 4: Vérifier que le projet reste lisible et que les deux cibles buildent**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project Wanderback.xcodeproj -list
```
Attendu : `Targets: Wanderback, WanderbackMac` et `Schemes: Wanderback, WanderbackMac`.

Puis la build Mac ET la build tvOS des contraintes globales. Attendu : `** BUILD SUCCEEDED **` pour les deux. En cas d'erreur de compilation Swift sur la build Mac (API indisponible en macOS 26), corriger au cas par cas avec `#if os(macOS)` — aucune n'est attendue (`focusSection` existe depuis macOS 13, `onExitCommand` depuis macOS 10.15, `@Observable`/SwiftData/MapKit SwiftUI depuis macOS 14). Ce qui s'est réellement passé : `MKReverseGeocodingRequest` exigeait macOS 26, ce qui a conduit à relever la cible de macOS 14 à macOS 26.

- [ ] **Step 5: Commit**

```bash
git add Wanderback.xcodeproj Wanderback/WanderbackMac.entitlements
git commit -m "Ajoute la cible macOS WanderbackMac (sources partagées, sandbox + accès Photos)"
```

---

### Task 3: Icône macOS aplatie depuis les couches parallax

**Files:**
- Create: `scripts/generate-mac-icon.swift`
- Create: `Wanderback/Assets.xcassets/AppIcon.appiconset/Contents.json` (+ 10 PNG générés)
- Modify: `Wanderback.xcodeproj/project.pbxproj` (configs `AC0000000000000000000007` et `AC0000000000000000000008`)

**Interfaces:**
- Consumes: cible `WanderbackMac` (tâche 2).
- Produces: appiconset `AppIcon` compilé dans l'app Mac (`Contents/Resources/AppIcon.icns`).

- [ ] **Step 1: Écrire `scripts/generate-mac-icon.swift`**

Les 3 couches (1280×768 chacune) sont dessinées aspect-fill avec le même facteur d'échelle (alignement du parallax préservé), recadrées au carré 1024, coins arrondis façon macOS, puis déclinées en 10 tailles.

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

let out = assets.appendingPathComponent("AppIcon.appiconset")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func renderIcon(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let side = CGFloat(pixels)
    // Rayon des icônes macOS : ~185/824 du canvas utile, appliqué plein cadre ici
    let radius = side * 234.0 / 1024.0
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: side, height: side),
                 xRadius: radius, yRadius: radius).addClip()
    for layer in layers {
        let scale = max(side / layer.size.width, side / layer.size.height)
        let w = layer.size.width * scale
        let h = layer.size.height * scale
        layer.draw(in: NSRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h),
                   from: .zero, operation: .sourceOver, fraction: 1)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let slots: [(name: String, pixels: Int)] = [
    ("icon_16", 16), ("icon_16@2x", 32),
    ("icon_32", 32), ("icon_32@2x", 64),
    ("icon_128", 128), ("icon_128@2x", 256),
    ("icon_256", 256), ("icon_256@2x", 512),
    ("icon_512", 512), ("icon_512@2x", 1024),
]
for slot in slots {
    try renderIcon(pixels: slot.pixels)
        .write(to: out.appendingPathComponent("\(slot.name).png"))
    print("✓ \(slot.name).png (\(slot.pixels)px)")
}
```

- [ ] **Step 2: Créer `Wanderback/Assets.xcassets/AppIcon.appiconset/Contents.json`**

```json
{
  "images" : [
    { "filename" : "icon_16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 3: Générer les PNG**

```bash
cd "/Users/bastienmicha/Claude Projects/Wanderback"
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift scripts/generate-mac-icon.swift
ls Wanderback/Assets.xcassets/AppIcon.appiconset/
```
Attendu : 10 lignes `✓ …`, puis 10 PNG + Contents.json listés. Ouvrir `icon_512@2x.png` (outil Read) pour contrôler visuellement le rendu (coins arrondis, composition lisible).

- [ ] **Step 4: Référencer l'icône dans la cible Mac**

Dans `project.pbxproj`, ajouter dans les `buildSettings` des deux configs `AC0000000000000000000007` et `AC0000000000000000000008` (ordre alphabétique, avant `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`) :

```
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
```

- [ ] **Step 5: Vérifier**

Build Mac (contraintes globales) : `** BUILD SUCCEEDED **`, puis :
```bash
ls "build/Debug/Wanderback.app/Contents/Resources/" | grep -i appicon
```
Attendu : `AppIcon.icns`. Build tvOS : toujours verte (l'appiconset idiome `mac` est ignoré par actool tvOS).

- [ ] **Step 6: Commit**

```bash
git add scripts/generate-mac-icon.swift "Wanderback/Assets.xcassets/AppIcon.appiconset" Wanderback.xcodeproj/project.pbxproj
git commit -m "Icône macOS aplatie depuis les couches parallax tvOS"
```

---

### Task 4: Fenêtre macOS et message d'erreur Photos adapté

**Files:**
- Modify: `Wanderback/App/WanderbackApp.swift`
- Modify: `Wanderback/ViewModels/PhotoLibraryViewModel.swift:125`

**Interfaces:**
- Consumes: cible `WanderbackMac` (tâche 2).
- Produces: fenêtre par défaut 1280×720, minimum 1024×640 ; message d'erreur d'accès Photos correct par plateforme.

- [ ] **Step 1: Adapter `WanderbackApp.swift`**

```swift
import SwiftUI
import SwiftData

@main
struct WanderbackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 1024, minHeight: 640)
                #endif
        }
        .modelContainer(for: LocationCache.self)
        #if os(macOS)
        .defaultSize(width: 1280, height: 720)
        #endif
    }
}
```

- [ ] **Step 2: Message d'erreur Photos par plateforme**

Dans `PhotoLibraryViewModel.swift`, remplacer la ligne 125 :

```swift
            #if os(macOS)
            errorMessage = "Wanderback a besoin d'accéder à vos photos pour fonctionner. Autorisez l'accès dans Réglages Système > Confidentialité et sécurité > Photos."
            #else
            errorMessage = "Wanderback a besoin d'accéder à vos photos pour fonctionner. Autorisez l'accès dans Réglages > Confidentialité > Photos."
            #endif
```

- [ ] **Step 3: Vérifier les deux builds** (commandes des contraintes globales) — attendu : `** BUILD SUCCEEDED **` ×2.

- [ ] **Step 4: Commit**

```bash
git add Wanderback/App/WanderbackApp.swift Wanderback/ViewModels/PhotoLibraryViewModel.swift
git commit -m "Fenêtre macOS (1280×720, min 1024×640) et message Photos adapté"
```

---

### Task 5: Échelle d'interface `Theme.scale` (UI TV → fenêtre Mac)

**Files:**
- Modify: `Wanderback/DesignSystem/Theme.swift`
- Modify: `Wanderback/Views/AnswerOptionsView.swift`
- Modify: `Wanderback/Views/GameView.swift`
- Modify: `Wanderback/Views/HomeView.swift`
- Modify: `Wanderback/Views/RevealView.swift`
- Modify: `Wanderback/Views/SummaryView.swift`
- Modify: `Wanderback/Views/LoadingView.swift`
- Modify: `Wanderback/Views/NotEnoughPlacesView.swift`
- Modify: `Wanderback/Views/ContentView.swift`

**Interfaces:**
- Consumes: rien de nouveau.
- Produces: `Theme.scale: CGFloat` (0.62 sur macOS, 1.0 ailleurs) et les helpers `CGFloat.scaled` / `Int.scaled` (`var scaled: CGFloat`, = valeur × `Theme.scale`), utilisés par toutes les vues.

- [ ] **Step 1: Ajouter l'échelle dans `Theme.swift`**

À la fin de l'`enum Theme` (après `focusAnimation`) :

```swift
    // MARK: - Échelle plateforme

    /// L'UI est calibrée pour un canvas TV 1920×1080 regardé à 3 m ; en fenêtre
    /// Mac (~1280 pt) typo et espacements sont réduits d'un facteur global.
    #if os(macOS)
    static let scale: CGFloat = 0.62
    #else
    static let scale: CGFloat = 1.0
    #endif
```

Après l'extension `Color` existante :

```swift
extension CGFloat {
    /// Valeur de design (canvas TV) ramenée à l'échelle de la plateforme.
    var scaled: CGFloat { self * Theme.scale }
}

extension Int {
    var scaled: CGFloat { CGFloat(self) * Theme.scale }
}
```

- [ ] **Step 2: Appliquer l'échelle dans les styles partagés de `Theme.swift`**

Règle mécanique appliquée dans toute cette tâche : chaque littéral de **taille de police, padding, spacing, dimension fixe de frame et corner radius** devient `N.scaled`. Ne PAS scaler : `lineWidth`, rayons/offsets d'ombre, opacités, durées, `startRadius`/`endRadius` des dégradés, tailles passées à `PhotoImageLoader` (pixels), dimensions des pins de carte.

- `GradientPillLabel` : `.font(.system(size: fontSize.scaled, …))`, `.padding(.horizontal, horizontalPadding.scaled)`, `.padding(.vertical, verticalPadding.scaled)` (les appelants gardent leurs littéraux 104/24/32, etc.).
- `SecondaryPillLabel` : idem (fontSize, horizontalPadding, verticalPadding en `.scaled`).
- `GradientText` : `.font(.system(size: size.scaled, weight: weight))`.

- [ ] **Step 3: Appliquer la règle dans les vues** (littéraux exacts à transformer)

- `AnswerOptionsView.swift` : `HStack(spacing: 24.scaled)` ; fonts `28.scaled`/`21.scaled` ; `.padding(.horizontal, 28.scaled)`, `.padding(.vertical, 24.scaled)` ; les 3 `cornerRadius: 20` → `20.scaled`.
- `GameView.swift` : topBar fonts `28` (GradientText, déjà scalé), `24`×2 → `.scaled` ; paddings `56`/`36` ; `HStack(spacing: 32.scaled)` ; timerRing : `.frame(width: 68.scaled, height: 68.scaled)` et font `24.scaled` ; bottomSection : font `26.scaled`, `VStack(… spacing: 24.scaled)`, paddings `56`/`44` → `.scaled`.
- `HomeView.swift` : `VStack(spacing: 44.scaled)` ; header `spacing: 14.scaled`, font `27.scaled` ; modeSelection `spacing: 34.scaled` ; modeTileLabel : spacings `16`/`6`, icône font `24`, `.frame(width: 52.scaled, height: 52.scaled)`, fonts `34`/`22`, `.frame(width: (500 - 2 * 34).scaled, …)`, `.padding(34.scaled)` ; ModeTileLabel : les 2 `cornerRadius: 28` → `28.scaled` ; roundsSelection : `spacing: 28.scaled`, fonts `24`/`32` ; RoundCircleLabel : `.frame(width: 96.scaled, height: 96.scaled)` ; statsRow : spacings `10`/`52`, fonts `22`/`19` ; playButton : `HStack(spacing: 16.scaled)`, font `24.scaled`.
- `RevealView.swift` : resultBadge : `spacing: 10.scaled`, fonts `22`/`26`, paddings `36`/`16`, `.padding(.top, 44.scaled)` ; centerContent : `spacing: 16.scaled`, fonts `104`/`32`/`24`/`30`, paddings `70`/`40`/`8`, `cornerRadius: 28` ×3 → `.scaled`, `.padding(.top, 280.scaled)`, `.padding(.horizontal, 100.scaled)` ; sameDayThumbnails : `spacing: 14.scaled`, `.frame(width: 148.scaled, height: 100.scaled)`, `cornerRadius: 14` ×2, font `19.scaled`, `.padding(.leading, 6.scaled)` ; nextButton : `HStack(spacing: 12.scaled)`, font `22.scaled` ; bas d'écran : paddings `56`/`44` → `.scaled`. Pins et caméra carte : inchangés.
- `SummaryView.swift` : `VStack(spacing: 36.scaled)`, `spacing: 10.scaled`, fonts `30`/`26`/`25`, GradientText `96` (déjà scalé), `HStack(spacing: 30.scaled)` et `spacing: 14.scaled`, font `20.scaled`, statsLine `spacing: 56.scaled`, `.padding(.bottom, 70.scaled)`. Pins carte : inchangés.
- `LoadingView.swift` : `VStack(spacing: 44.scaled)`, fonts `28`/`24`/`24`, `spacing: 20.scaled` ; globe : frames `140`/`64` → `.scaled` ; progressBar : `.frame(width: 900.scaled, height: 12.scaled)` et segment indéterminé `.frame(width: 200.scaled)`.
- `NotEnoughPlacesView.swift` : `VStack(spacing: 32.scaled)`, fonts `52`/`28`/`24`/`18`, `HStack(spacing: 30.scaled)` et `spacing: 12.scaled`, `.padding(.top, 8.scaled)`, `.padding(.horizontal, 200.scaled)` ; badge : frames `120`/`52`/`26` → `.scaled` ; tipCard : font `24.scaled`, paddings `30`/`18`, `cornerRadius: 16.scaled`.
- `ContentView.swift` (errorView) : frame `120.scaled`, fonts `48.scaled`/`28.scaled`, `.padding(.horizontal, 200.scaled)`, `VStack(spacing: 32.scaled)`.

- [ ] **Step 4: Vérifier les deux builds** — attendu : `** BUILD SUCCEEDED **` ×2. Sur tvOS, `scale = 1.0` : rendu strictement identique.

- [ ] **Step 5: Commit**

```bash
git add Wanderback/DesignSystem/Theme.swift Wanderback/Views
git commit -m "Échelle d'interface Theme.scale : UI TV réduite à 62 % en fenêtre macOS"
```

---

### Task 6: Effets de survol souris sur les boutons

**Files:**
- Modify: `Wanderback/DesignSystem/Theme.swift` (GradientPillLabel, SecondaryPillLabel)
- Modify: `Wanderback/Views/AnswerOptionsView.swift` (AnswerCardLabel)
- Modify: `Wanderback/Views/HomeView.swift` (ModeTileLabel, RoundCircleLabel)

**Interfaces:**
- Consumes: styles de boutons existants.
- Produces: chaque label de style expose le même rendu « focus » au survol souris (le focus tvOS et le survol macOS partagent le même visuel).

- [ ] **Step 1: Motif appliqué aux 5 labels de styles**

Dans chaque struct label privée, ajouter un état de survol et remplacer les lectures de `isFocused` par `isHighlighted` (`.onHover` existe sur tvOS 16+ mais n'y est jamais déclenché — pas de `#if` nécessaire). Exemple complet sur `AnswerCardLabel` :

```swift
    private struct AnswerCardLabel: View {
        @Environment(\.isFocused) private var isFocused
        @State private var isHovered = false
        let configuration: ButtonStyle.Configuration

        private var isHighlighted: Bool { isFocused || isHovered }

        var body: some View {
            configuration.label
                .foregroundStyle(isHighlighted ? Theme.inkDark : .white)
                .background {
                    if isHighlighted {
                        RoundedRectangle(cornerRadius: 20.scaled).fill(Color.white)
                    } else {
                        RoundedRectangle(cornerRadius: 20.scaled)
                            .fill(Theme.answerSurface)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20.scaled))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20.scaled)
                        .strokeBorder(isHighlighted ? Color.clear : Theme.answerBorder, lineWidth: 3)
                )
                .shadow(color: isHighlighted ? Theme.focusShadow : .clear, radius: 25, y: 20)
                .scaleEffect(isHighlighted ? 1.07 : 1.0)
                .animation(Theme.focusAnimation, value: isHighlighted)
                .onHover { isHovered = $0 }
        }
    }
```

- [ ] **Step 2: Décliner le même motif sur les 4 autres labels**

- `GradientPillLabel` (Theme.swift) : `isHighlighted` remplace `isFocused` dans l'ombre, le `scaleEffect` et l'`animation` ; ajouter `.onHover { isHovered = $0 }`.
- `SecondaryPillLabel` (Theme.swift) : idem (foregroundStyle, background, overlay, shadow, scaleEffect, animation).
- `ModeTileLabel` (HomeView.swift) : `isHighlighted` remplace `isFocused` dans l'opacité de bordure, `.opacity(isSelected || isHighlighted ? 1 : 0.65)`, `scaleEffect(isHighlighted ? 1.08 : …)` et l'`animation` ; ajouter `.onHover`.
- `RoundCircleLabel` (HomeView.swift) : `let highlighted = isSelected || isFocused || isHovered` ; `scaleEffect((isFocused || isHovered) ? 1.1 : 1.0)`, shadow sur `isFocused || isHovered` ; `animation(…, value: isHovered)` en plus ; ajouter `.onHover`.

- [ ] **Step 3: Vérifier les deux builds** — attendu : `** BUILD SUCCEEDED **` ×2.

- [ ] **Step 4: Commit**

```bash
git add Wanderback/DesignSystem/Theme.swift Wanderback/Views/AnswerOptionsView.swift Wanderback/Views/HomeView.swift
git commit -m "Survol souris sur les boutons : même visuel que le focus tvOS"
```

---

### Task 7: Raccourcis clavier macOS (1–4, Entrée)

**Files:**
- Create: `Wanderback/Platform/KeyboardShortcuts.swift`
- Modify: `Wanderback/Views/AnswerOptionsView.swift`
- Modify: `Wanderback/Views/RevealView.swift`
- Modify: `Wanderback/Views/SummaryView.swift`
- Modify: `Wanderback/Views/HomeView.swift`

**Interfaces:**
- Consumes: rien de nouveau.
- Produces: `View.macKeyboardShortcut(_ key: Character) -> some View` (raccourci sans modificateur, no-op sur tvOS) et `View.macDefaultActionShortcut() -> some View` (touche Entrée, no-op sur tvOS).

- [ ] **Step 1: Créer `Wanderback/Platform/KeyboardShortcuts.swift`**

`keyboardShortcut` n'existe pas sur tvOS : les deux helpers compilent la branche macOS seulement.

```swift
import SwiftUI

extension View {
    /// Raccourci clavier macOS sans modificateur ; no-op sur tvOS.
    @ViewBuilder
    func macKeyboardShortcut(_ key: Character) -> some View {
        #if os(macOS)
        self.keyboardShortcut(KeyEquivalent(key), modifiers: [])
        #else
        self
        #endif
    }

    /// Touche Entrée (action par défaut) sur macOS ; no-op sur tvOS.
    @ViewBuilder
    func macDefaultActionShortcut() -> some View {
        #if os(macOS)
        self.keyboardShortcut(.defaultAction)
        #else
        self
        #endif
    }
}
```

- [ ] **Step 2: Touches 1–4 sur les cartes réponse**

Dans `AnswerOptionsView.swift`, passer le `ForEach` sur les indices pour dériver la touche :

```swift
        HStack(spacing: 24.scaled) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                Button {
                    onSelect(option)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
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
                .focused($focusedOption, equals: option.id)
                .macKeyboardShortcut(Character("\(index + 1)"))
            }
        }
```

- [ ] **Step 3: Entrée = action principale**

- `RevealView.swift` : ajouter `.macDefaultActionShortcut()` au `nextButton` (après `.focused($nextButtonFocused)`).
- `SummaryView.swift` : ajouter `.macDefaultActionShortcut()` au bouton « Rejouer » (après `.focused($replayFocused)`).
- `HomeView.swift` : ajouter `.macDefaultActionShortcut()` au `playButton` (après `.focused($focusedElement, equals: .play)`).

(Échap est déjà géré : `.onExitCommand` de `ContentView` correspond à la touche Échap sur macOS.)

- [ ] **Step 4: Vérifier les deux builds** — attendu : `** BUILD SUCCEEDED **` ×2.

- [ ] **Step 5: Commit**

```bash
git add Wanderback/Platform/KeyboardShortcuts.swift Wanderback/Views
git commit -m "Raccourcis clavier macOS : 1-4 pour répondre, Entrée pour continuer"
```

---

### Task 8: Vérification visuelle et fonctionnelle sur Mac + README

**Files:**
- Modify: `README.md` (mention plateformes)
- Aucun autre fichier attendu — tâche de vérification ; corriger ce qui est découvert.

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces: app validée visuellement écran par écran ; README à jour.

- [ ] **Step 1: Build signée et lancement en mode démo**

```bash
cd "/Users/bastienmicha/Claude Projects/Wanderback"
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project Wanderback.xcodeproj -scheme WanderbackMac \
  -destination 'platform=macOS' -configuration Debug build SYMROOT=build -quiet
"build/Debug/Wanderback.app/Contents/MacOS/Wanderback" -demoMode &
```
(`open -a` interdit — binaire lancé directement, cf. contraintes globales. Le flag `-demoMode` évite le prompt Photos pour cette passe visuelle.)

- [ ] **Step 2: Capturer et inspecter chaque écran**

Pour chaque écran : relancer avec `-demoMode -screen game`, `-screen reveal`, `-screen summary`, puis sans `-screen` (accueil), attendre ~5 s et :
```bash
screencapture -x /private/tmp/claude-501/-Users-bastienmicha-Claude-Projects-Wanderback/4d82a72e-d0a6-42ca-81dc-92428c2ab857/scratchpad/mac-<écran>.png
```
Lire chaque capture (outil Read) et vérifier : rien de tronqué ni de disproportionné en 1280×720, textes lisibles, cartes MapKit affichées. Ajuster `Theme.scale` (±0.05) ou un padding précis si un écran déborde, rebuilder, recapturer.

- [ ] **Step 3: Test avec la vraie photothèque (interaction utilisateur)**

Lancer sans `-demoMode` ; macOS affiche le prompt d'accès Photos (l'utilisateur doit cliquer « Autoriser l'accès complet »). Vérifier : indexation → accueil (mosaïque de vraies photos) → partie complète en Souvenir puis Challenge → révélation (zoom carte) → résumé. Vérifier au passage : survol souris sur les 4 cartes réponse, touches 1–4, Entrée pour « Round suivant », Échap pour quitter la partie, redimensionnement de la fenêtre jusqu'au minimum 1024×640, plein écran macOS. Demander à l'utilisateur de confirmer que l'expérience lui convient avant de continuer.

- [ ] **Step 4: Mettre à jour `README.md`**

- Ligne 3 : `> Jeu de reconnaissance de lieux à partir de tes photos de vacances · Apple TV (tvOS) & Mac (macOS)`
- Ligne 5 : remplacer « est une application tvOS » par « est une application tvOS et macOS ».
- Section Prérequis, ajouter : `- ou un Mac sous macOS 26+ (cible WanderbackMac)`.

- [ ] **Step 5: Vérifier les deux builds une dernière fois, puis commit**

```bash
git add README.md
git commit -m "Valide le portage macOS et documente la plateforme dans le README"
```
(Si des ajustements de code ont été faits aux steps 2–3, les inclure dans ce commit avec un message adapté.)

---

### Task 9: Archive et upload TestFlight macOS

**Files:**
- Modify: `Wanderback.xcodeproj/project.pbxproj` (CURRENT_PROJECT_VERSION, 4 emplacements : 2 configs tvOS + 2 configs Mac)
- Create (scratchpad, non versionné) : `ExportOptionsMac.plist`

**Interfaces:**
- Consumes: app validée (tâche 8) ; clé API ASC `~/.appstoreconnect/private_keys/AuthKey_P42BG7P56Z.p8`.
- Produces: build macOS visible dans TestFlight.

**Préalable utilisateur (bloquant) :** le record App Store Connect `com.bastien.Wanderback` est tvOS ; l'utilisateur doit ajouter la plateforme **macOS** à l'app dans App Store Connect (apps > Wanderback > + plateforme) avant l'upload. Demander confirmation explicite avant d'uploader (action externe).

- [ ] **Step 1: Incrémenter le build number**

Dans `project.pbxproj`, passer `CURRENT_PROJECT_VERSION = 2;` à `3` dans les **4** configs (tvOS Debug/Release + Mac Debug/Release) — chaque upload exige un numéro unique, et les deux plateformes du même app record partagent la numérotation de version marketing.

- [ ] **Step 2: Archiver**

```bash
cd "/Users/bastienmicha/Claude Projects/Wanderback"
SCRATCH=/private/tmp/claude-501/-Users-bastienmicha-Claude-Projects-Wanderback/4d82a72e-d0a6-42ca-81dc-92428c2ab857/scratchpad
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild archive \
  -project Wanderback.xcodeproj -scheme WanderbackMac \
  -destination 'generic/platform=macOS' \
  -archivePath "$SCRATCH/WanderbackMac.xcarchive" -allowProvisioningUpdates
```
Attendu : `** ARCHIVE SUCCEEDED **`.

- [ ] **Step 3: Exporter**

`$SCRATCH/ExportOptionsMac.plist` :
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
  -archivePath "$SCRATCH/WanderbackMac.xcarchive" \
  -exportOptionsPlist "$SCRATCH/ExportOptionsMac.plist" \
  -exportPath "$SCRATCH/export-mac" -allowProvisioningUpdates
```
Attendu : `** EXPORT SUCCEEDED **` et un `Wanderback.pkg` dans `export-mac/`.

- [ ] **Step 4: Uploader (après confirmation utilisateur)**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun altool --upload-app \
  -f "$SCRATCH/export-mac/Wanderback.pkg" -t macos \
  --apiKey P42BG7P56Z --apiIssuer a6ac781b-dc96-4846-a507-ca104b8d7782
```
Attendu : `No errors uploading`. (Rappel mémoire : les builds SDK bêta passent sur TestFlight mais pas en release App Store.)

- [ ] **Step 5: Commit**

```bash
git add Wanderback.xcodeproj/project.pbxproj
git commit -m "Build 3 : premier upload TestFlight macOS"
```
