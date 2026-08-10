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
let side = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
guard let ctx = CGContext(
    data: nil,
    width: side, height: side,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace, bitmapInfo: bitmapInfo.rawValue
) else {
    fatalError("Impossible de créer un contexte CGContext avec RGBX opaque")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
for layer in layers {
    let scale = max(CGFloat(side) / layer.size.width, CGFloat(side) / layer.size.height)
    let w = layer.size.width * scale
    let h = layer.size.height * scale
    layer.draw(in: NSRect(x: (CGFloat(side) - w) / 2, y: (CGFloat(side) - h) / 2, width: w, height: h),
               from: .zero, operation: .sourceOver, fraction: 1)
}
NSGraphicsContext.restoreGraphicsState()

guard let cgImage = ctx.makeImage() else {
    fatalError("Impossible de créer une image à partir du contexte")
}
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Impossible de générer le PNG")
}
try pngData.write(to: out.appendingPathComponent("icon_1024.png"))
print("✓ icon_1024.png (1024px, sans alpha)")
