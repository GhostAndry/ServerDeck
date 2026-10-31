import AppKit
import CoreGraphics

let size = CGSize(width: 1024, height: 1024)
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: Int(size.width),
    height: Int(size.height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create graphics context")
}

// Helper color functions
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    return CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}

func hexColor(_ hex: UInt32, alpha: CGFloat = 1.0) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return color(r, g, b, alpha)
}

// 1. Background Gradient (Deep space obsidian & dark sapphire)
let bgColors = [
    hexColor(0x111827), // Deep slate navy
    hexColor(0x080B11)  // Dark obsidian
] as CFArray

if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
    context.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: 512, y: 560),
        startRadius: 50,
        endCenter: CGPoint(x: 512, y: 512),
        endRadius: 700,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

// 2. Subtle Circuit Grid Accent in Background
context.saveGState()
context.setStrokeColor(hexColor(0x38BDF8, alpha: 0.04))
context.setLineWidth(1.0)
let gridSize: CGFloat = 64
for x in stride(from: CGFloat(64), to: 960, by: gridSize) {
    context.move(to: CGPoint(x: x, y: 64))
    context.addLine(to: CGPoint(x: x, y: 960))
}
for y in stride(from: CGFloat(64), to: 960, by: gridSize) {
    context.move(to: CGPoint(x: 64, y: y))
    context.addLine(to: CGPoint(x: 960, y: y))
}
context.strokePath()
context.restoreGState()

// 3. Ambient Glow behind the Server Deck
context.saveGState()
let glowColors = [
    hexColor(0x06B6D4, alpha: 0.22), // Electric cyan glow
    hexColor(0x3B82F6, alpha: 0.12),
    hexColor(0x000000, alpha: 0.0)
] as CFArray
if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 0.45, 1.0]) {
    context.drawRadialGradient(
        glowGrad,
        startCenter: CGPoint(x: 512, y: 512),
        startRadius: 60,
        endCenter: CGPoint(x: 512, y: 512),
        endRadius: 420,
        options: []
    )
}
context.restoreGState()

// 4. Draw 3 Server Blades (The "Deck")
let bladeWidth: CGFloat = 640
let bladeHeight: CGFloat = 108
let cornerRadius: CGFloat = 22
let bladeYPositions: [CGFloat] = [320, 460, 600] // Coordinates from bottom (CoreGraphics origin is bottom-left)

for (index, yPos) in bladeYPositions.enumerated() {
    let rect = CGRect(x: (size.width - bladeWidth) / 2, y: yPos, width: bladeWidth, height: bladeHeight)
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    context.saveGState()
    
    // Blade Shadow
    context.setShadow(
        offset: CGSize(width: 0, height: -12),
        blur: 24,
        color: hexColor(0x000000, alpha: 0.55)
    )

    // Blade Gradient Fill
    let bladeColors = [
        hexColor(0x242F46), // Highlighted dark metal top
        hexColor(0x141A29)  // Deep metallic bottom
    ] as CFArray
    if let bladeGrad = CGGradient(colorsSpace: colorSpace, colors: bladeColors, locations: [0.0, 1.0]) {
        context.addPath(path)
        context.clip()
        context.drawLinearGradient(
            bladeGrad,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.minY),
            options: []
        )
    }
    context.restoreGState()

    // Blade Border & Rim Highlight
    context.saveGState()
    context.addPath(path)
    context.setStrokeColor(hexColor(0x475569, alpha: 0.5))
    context.setLineWidth(1.5)
    context.strokePath()

    // Inner top highlight line
    let innerHighlightRect = rect.insetBy(dx: 2, dy: 2)
    let innerPath = CGPath(roundedRect: innerHighlightRect, cornerWidth: cornerRadius - 2, cornerHeight: cornerRadius - 2, transform: nil)
    context.addPath(innerPath)
    context.setStrokeColor(hexColor(0x94A3B8, alpha: 0.2))
    context.setLineWidth(1.0)
    context.strokePath()
    context.restoreGState()

    // Blade Features (Vents & Status LEDs)
    context.saveGState()

    // Status LEDs on the Left
    let ledY = rect.midY
    let ledX1 = rect.minX + 38
    let ledX2 = rect.minX + 62
    let ledRadius: CGFloat = 6.0

    // Primary Active LED (Emerald / Cyan)
    let ledColor = (index == 2) ? hexColor(0x10B981) : hexColor(0x06B6D4)
    let ledGlowColor = (index == 2) ? hexColor(0x10B981, alpha: 0.6) : hexColor(0x06B6D4, alpha: 0.6)

    // Glow under LED
    context.setShadow(offset: .zero, blur: 14, color: ledGlowColor)
    context.setFillColor(ledColor)
    context.fillEllipse(in: CGRect(x: ledX1 - ledRadius, y: ledY - ledRadius, width: ledRadius * 2, height: ledRadius * 2))

    // Secondary Activity LED
    let led2Color = hexColor(0x38BDF8, alpha: 0.75)
    context.setShadow(offset: .zero, blur: 8, color: hexColor(0x38BDF8, alpha: 0.4))
    context.setFillColor(led2Color)
    context.fillEllipse(in: CGRect(x: ledX2 - 4, y: ledY - 4, width: 8, height: 8))

    // Divider notch
    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.setStrokeColor(hexColor(0x334155, alpha: 0.6))
    context.setLineWidth(1.5)
    context.move(to: CGPoint(x: rect.minX + 88, y: rect.minY + 22))
    context.addLine(to: CGPoint(x: rect.minX + 88, y: rect.maxY - 22))
    context.strokePath()

    // Server Chassis Ventilation Slots (horizontal pill cuts)
    let ventStartX = rect.minX + 112
    let ventEndX = rect.maxX - 96
    let ventWidth: CGFloat = 26
    let ventHeight: CGFloat = 6
    let ventGap: CGFloat = 16

    context.setFillColor(hexColor(0x0B0F19))
    var currentX = ventStartX
    while currentX + ventWidth < ventEndX {
        // Double row of vents
        let ventRect1 = CGRect(x: currentX, y: ledY + 8, width: ventWidth, height: ventHeight)
        let ventRect2 = CGRect(x: currentX, y: ledY - 14, width: ventWidth, height: ventHeight)
        context.addPath(CGPath(roundedRect: ventRect1, cornerWidth: 3, cornerHeight: 3, transform: nil))
        context.addPath(CGPath(roundedRect: ventRect2, cornerWidth: 3, cornerHeight: 3, transform: nil))
        context.fillPath()
        currentX += ventWidth + ventGap
    }

    // Right-side Drive Bay / Lock Notch
    let bayRect = CGRect(x: rect.maxX - 68, y: ledY - 16, width: 34, height: 32)
    context.addPath(CGPath(roundedRect: bayRect, cornerWidth: 6, cornerHeight: 6, transform: nil))
    context.setFillColor(hexColor(0x172033))
    context.fillPath()
    context.addPath(CGPath(roundedRect: bayRect, cornerWidth: 6, cornerHeight: 6, transform: nil))
    context.setStrokeColor(hexColor(0x38BDF8, alpha: 0.35))
    context.setLineWidth(1.0)
    context.strokePath()

    context.restoreGState()
}

// 5. Central Dynamic Pulse / Network Telemetry Accent
context.saveGState()
context.setShadow(offset: .zero, blur: 20, color: hexColor(0x00F0FF, alpha: 0.8))
context.setStrokeColor(hexColor(0x00F0FF, alpha: 0.95))
context.setLineWidth(4.5)
context.setLineCap(.round)
context.setLineJoin(.round)

let pulsePath = CGMutablePath()
pulsePath.move(to: CGPoint(x: 280, y: 514))
pulsePath.addLine(to: CGPoint(x: 420, y: 514))
pulsePath.addLine(to: CGPoint(x: 460, y: 554))
pulsePath.addLine(to: CGPoint(x: 500, y: 460))
pulsePath.addLine(to: CGPoint(x: 540, y: 568))
pulsePath.addLine(to: CGPoint(x: 576, y: 494))
pulsePath.addLine(to: CGPoint(x: 606, y: 514))
pulsePath.addLine(to: CGPoint(x: 744, y: 514))

context.addPath(pulsePath)
context.strokePath()

// Inner intense white core for pulse
context.setShadow(offset: .zero, blur: 0, color: nil)
context.setStrokeColor(hexColor(0xFFFFFF, alpha: 0.9))
context.setLineWidth(1.8)
context.addPath(pulsePath)
context.strokePath()
context.restoreGState()

// 6. Modern Top Glassmorphism Sheen
context.saveGState()
let sheenRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
let sheenColors = [
    hexColor(0xFFFFFF, alpha: 0.08),
    hexColor(0xFFFFFF, alpha: 0.0)
] as CFArray
if let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 1.0]) {
    context.drawLinearGradient(
        sheenGrad,
        start: CGPoint(x: 0, y: 1024),
        end: CGPoint(x: 0, y: 500),
        options: []
    )
}
context.restoreGState()

// 7. Save to PNG
guard let image = context.makeImage() else {
    fatalError("Failed to create image from context")
}

let bitmapRep = NSBitmapImageRep(cgImage: image)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to convert image to PNG")
}

let outputPath = "/Users/andrea/Documents/Code/ServerDeck/ios/Sources/ServerDeck/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Successfully generated AppIcon-1024.png")
} catch {
    fatalError("Error saving image: \(error)")
}
