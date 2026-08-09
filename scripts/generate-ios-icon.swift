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
