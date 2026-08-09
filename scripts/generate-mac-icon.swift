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
    // Grille d'icône macOS : le contenu visible occupe un carré de 824/1024 du canvas,
    // centré dans un cadre transparent, avec un rayon de coin de 185.4/1024 du côté.
    let iconSide = side * 824.0 / 1024.0
    let radius = side * 185.4 / 1024.0
    let origin = (side - iconSide) / 2
    NSBezierPath(roundedRect: NSRect(x: origin, y: origin, width: iconSide, height: iconSide),
                 xRadius: radius, yRadius: radius).addClip()
    for layer in layers {
        let scale = max(iconSide / layer.size.width, iconSide / layer.size.height)
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
