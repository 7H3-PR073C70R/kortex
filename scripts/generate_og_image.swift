import AppKit
import Foundation

// MARK: - Color Palette (Parity with Flutter AppMaterialColors)
func colorFromHex(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    return NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
        green: CGFloat((hex >> 8) & 0xFF) / 255.0,
        blue: CGFloat(hex & 0xFF) / 255.0,
        alpha: alpha
    )
}

let darkCanvas = colorFromHex(0x0D0D0F)
let darkCard = colorFromHex(0x141417)
let darkSurface = colorFromHex(0x1D1D22)
let mutedSage = colorFromHex(0x788C7E)
let warmOchre = colorFromHex(0xD4A373)
let quartzCyan = colorFromHex(0x5B8C93)
let deepGreen = colorFromHex(0x4A6B5D)
let recallAgain = colorFromHex(0xC86D51)
let recallEasy = colorFromHex(0x52796F)
let textPrimary = colorFromHex(0xFAFAFA)
let textSecondary = colorFromHex(0xA1A1AA)
let textMuted = colorFromHex(0x71717A)
let borderSubtle = colorFromHex(0xFFFFFF, alpha: 0.10)
let borderHighlight = colorFromHex(0xFFFFFF, alpha: 0.18)

let width: CGFloat = 1200
let height: CGFloat = 630
let canvasSize = NSSize(width: width, height: height)

let image = NSImage(size: canvasSize)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    print("Failed to get CGContext")
    exit(1)
}

// 1. Background Fill
ctx.setFillColor(darkCanvas.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

// 2. Ambient Radial Glows
let colorSpace = CGColorSpaceCreateDeviceRGB()
let glowColors = [
    mutedSage.withAlphaComponent(0.25).cgColor,
    quartzCyan.withAlphaComponent(0.12).cgColor,
    NSColor.clear.cgColor
] as CFArray
let glowLocations: [CGFloat] = [0.0, 0.45, 1.0]
if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: glowLocations) {
    ctx.drawRadialGradient(
        glowGrad,
        startCenter: CGPoint(x: 960, y: 380),
        startRadius: 10,
        endCenter: CGPoint(x: 960, y: 380),
        endRadius: 460,
        options: .drawsAfterEndLocation
    )
}

let ochreGlowColors = [
    warmOchre.withAlphaComponent(0.15).cgColor,
    NSColor.clear.cgColor
] as CFArray
if let ochreGrad = CGGradient(colorsSpace: colorSpace, colors: ochreGlowColors, locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(
        ochreGrad,
        startCenter: CGPoint(x: 200, y: 560),
        startRadius: 10,
        endCenter: CGPoint(x: 200, y: 560),
        endRadius: 360,
        options: .drawsAfterEndLocation
    )
}

// 3. Subtle Hairline Grid Pattern
ctx.setStrokeColor(colorFromHex(0xFFFFFF, alpha: 0.035).cgColor)
ctx.setLineWidth(1.0)
let gridSize: CGFloat = 40
for x in stride(from: CGFloat(0), to: width, by: gridSize) {
    ctx.move(to: CGPoint(x: x, y: 0))
    ctx.addLine(to: CGPoint(x: x, y: height))
}
for y in stride(from: CGFloat(0), to: height, by: gridSize) {
    ctx.move(to: CGPoint(x: 0, y: y))
    ctx.addLine(to: CGPoint(x: width, y: y))
}
ctx.strokePath()

// 4. Logo & Wordmark (Top Left, x: 80, y: height - 110)
let logoCenter = CGPoint(x: 105, y: height - 85)
let logoRadius: CGFloat = 25

// Draw Hexagon for Logo
let hexPath = CGMutablePath()
for i in 0..<6 {
    let angle = CGFloat(i) * CGFloat.pi / 3.0 - CGFloat.pi / 2.0
    let pt = CGPoint(x: logoCenter.x + logoRadius * cos(angle), y: logoCenter.y + logoRadius * sin(angle))
    if i == 0 {
        hexPath.move(to: pt)
    } else {
        hexPath.addLine(to: pt)
    }
}
hexPath.closeSubpath()
ctx.addPath(hexPath)
ctx.setStrokeColor(mutedSage.cgColor)
ctx.setLineWidth(2.8)
ctx.strokePath()

// Logo "K" inside Hexagon
ctx.setStrokeColor(warmOchre.cgColor)
ctx.setLineWidth(3.0)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: logoCenter.x - 9, y: logoCenter.y - 12))
ctx.addLine(to: CGPoint(x: logoCenter.x - 9, y: logoCenter.y + 12))
ctx.move(to: CGPoint(x: logoCenter.x - 9, y: logoCenter.y))
ctx.addLine(to: CGPoint(x: logoCenter.x + 9, y: logoCenter.y + 12))
ctx.move(to: CGPoint(x: logoCenter.x - 9, y: logoCenter.y))
ctx.addLine(to: CGPoint(x: logoCenter.x + 9, y: logoCenter.y - 12))
ctx.strokePath()

// Brand Title
let brandFont = NSFont.systemFont(ofSize: 24, weight: .heavy)
let brandAttrs: [NSAttributedString.Key: Any] = [
    .font: brandFont,
    .foregroundColor: textPrimary,
    .kern: 2.5
]
"KORTEXIFY".draw(at: CGPoint(x: 145, y: height - 97), withAttributes: brandAttrs)

// AI Study Workspace Tag
let tagFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .bold)
let tagAttrs: [NSAttributedString.Key: Any] = [
    .font: tagFont,
    .foregroundColor: mutedSage,
    .kern: 1.2
]
"AI STUDY WORKSPACE".draw(at: CGPoint(x: 305, y: height - 92), withAttributes: tagAttrs)

// 5. Main Headline — Stacked cleanly in 2 lines to avoid overlapping the card!
let h1Font = NSFont.systemFont(ofSize: 64, weight: .black)
let h1Attrs: [NSAttributedString.Key: Any] = [
    .font: h1Font,
    .foregroundColor: textPrimary,
    .kern: -1.5
]
"Forget about".draw(at: CGPoint(x: 80, y: height - 190), withAttributes: h1Attrs)

let italicSerif = NSFont(name: "Georgia-Italic", size: 68) ?? NSFont.systemFont(ofSize: 68, weight: .bold)
let italicAttrs: [NSAttributedString.Key: Any] = [
    .font: italicSerif,
    .foregroundColor: warmOchre,
    .kern: -1.0
]
"forgetting.".draw(at: CGPoint(x: 80, y: height - 268), withAttributes: italicAttrs)

// 6. Subtitle / Value Proposition
let subFont = NSFont.systemFont(ofSize: 19, weight: .medium)
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: subFont,
    .foregroundColor: textSecondary
]
let subText = "Turn lecture slides, textbooks, and past questions into\nadaptive spaced-repetition cards, CBT mocks & Socratic AI tutoring."
subText.draw(at: CGPoint(x: 80, y: height - 340), withAttributes: subAttrs)

// 7. Educational Scope Pills (2x2 grid to stay well clear of the card)
let row1Pills = ["🎓 BSc · HND · OND", "📚 MSc · PhD · Research"]
let row2Pills = ["⚡ JAMB · WAEC · NECO", "🌍 SAT · GRE · IELTS"]

let pillFont = NSFont.systemFont(ofSize: 12.5, weight: .bold)

var r1X: CGFloat = 80
let r1Y: CGFloat = height - 410
for pill in row1Pills {
    let size = pill.size(withAttributes: [.font: pillFont])
    let pillRect = CGRect(x: r1X, y: r1Y, width: size.width + 24, height: 32)
    let bgPath = NSBezierPath(roundedRect: pillRect, xRadius: 16, yRadius: 16)
    colorFromHex(0x1D1D22, alpha: 0.95).setFill()
    bgPath.fill()
    borderSubtle.setStroke()
    bgPath.lineWidth = 1.0
    bgPath.stroke()
    pill.draw(at: CGPoint(x: r1X + 12, y: r1Y + 7), withAttributes: [.font: pillFont, .foregroundColor: textPrimary])
    r1X += size.width + 36
}

var r2X: CGFloat = 80
let r2Y: CGFloat = height - 455
for pill in row2Pills {
    let size = pill.size(withAttributes: [.font: pillFont])
    let pillRect = CGRect(x: r2X, y: r2Y, width: size.width + 24, height: 32)
    let bgPath = NSBezierPath(roundedRect: pillRect, xRadius: 16, yRadius: 16)
    colorFromHex(0x1D1D22, alpha: 0.95).setFill()
    bgPath.fill()
    borderSubtle.setStroke()
    bgPath.lineWidth = 1.0
    bgPath.stroke()
    pill.draw(at: CGPoint(x: r2X + 12, y: r2Y + 7), withAttributes: [.font: pillFont, .foregroundColor: textPrimary])
    r2X += size.width + 36
}

// 8. Graphic Demonstration Bento Card on Right Side
let cardRect = CGRect(x: 740, y: 65, width: 390, height: 500)
let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 24, yRadius: 24)
darkCard.withAlphaComponent(0.94).setFill()
cardPath.fill()
borderHighlight.setStroke()
cardPath.lineWidth = 1.5
cardPath.stroke()

// Card Header
let cardTitleFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .bold)
"SPACED REPETITION ENGINE".draw(at: CGPoint(x: 765, y: 525), withAttributes: [
    .font: cardTitleFont,
    .foregroundColor: mutedSage,
    .kern: 1.0
])

// Flashcard Graphic inside Bento Card
let miniCardRect = CGRect(x: 765, y: 375, width: 340, height: 125)
let miniCardPath = NSBezierPath(roundedRect: miniCardRect, xRadius: 16, yRadius: 16)
darkSurface.setFill()
miniCardPath.fill()
borderSubtle.setStroke()
miniCardPath.lineWidth = 1.0
miniCardPath.stroke()

"QUESTION · ACTIVE RECALL".draw(at: CGPoint(x: 785, y: 465), withAttributes: [
    .font: NSFont.monospacedSystemFont(ofSize: 8.5, weight: .semibold),
    .foregroundColor: warmOchre,
    .kern: 0.8
])

"Which species attacks the benzene ring in nitration?".draw(in: CGRect(x: 785, y: 405, width: 300, height: 55), withAttributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .bold),
    .foregroundColor: textPrimary
])

"Answer: Nitronium ion (NO₂⁺) • Next review: 6 days".draw(at: CGPoint(x: 785, y: 388), withAttributes: [
    .font: NSFont.systemFont(ofSize: 10.5, weight: .semibold),
    .foregroundColor: recallEasy
])

// 9. Memory Curve Chart inside Card
ctx.setStrokeColor(colorFromHex(0xFFFFFF, alpha: 0.08).cgColor)
ctx.setLineWidth(1.0)
ctx.move(to: CGPoint(x: 765, y: 155))
ctx.addLine(to: CGPoint(x: 1105, y: 155))
ctx.move(to: CGPoint(x: 765, y: 225))
ctx.addLine(to: CGPoint(x: 1105, y: 225))
ctx.move(to: CGPoint(x: 765, y: 295))
ctx.addLine(to: CGPoint(x: 1105, y: 295))
ctx.strokePath()

// Forgetting curve (dashed terracotta red)
ctx.setStrokeColor(recallAgain.withAlphaComponent(0.75).cgColor)
ctx.setLineWidth(2.0)
ctx.setLineDash(phase: 0, lengths: [5, 4])
ctx.move(to: CGPoint(x: 775, y: 295))
ctx.addCurve(to: CGPoint(x: 935, y: 160), control1: CGPoint(x: 825, y: 205), control2: CGPoint(x: 875, y: 170))
ctx.strokePath()

// Active Spaced Reviews (Solid Cyan)
ctx.setStrokeColor(quartzCyan.cgColor)
ctx.setLineWidth(3.0)
ctx.setLineDash(phase: 0, lengths: [])

// Review 1
ctx.move(to: CGPoint(x: 775, y: 295))
ctx.addCurve(to: CGPoint(x: 835, y: 245), control1: CGPoint(x: 805, y: 260), control2: CGPoint(x: 825, y: 250))
// Jump 1
ctx.addLine(to: CGPoint(x: 835, y: 295))
// Review 2
ctx.addCurve(to: CGPoint(x: 925, y: 265), control1: CGPoint(x: 875, y: 280), control2: CGPoint(x: 905, y: 270))
// Jump 2
ctx.addLine(to: CGPoint(x: 925, y: 300))
// Review 3
ctx.addCurve(to: CGPoint(x: 1045, y: 285), control1: CGPoint(x: 975, y: 295), control2: CGPoint(x: 1015, y: 290))
// Final exam day point
ctx.addLine(to: CGPoint(x: 1085, y: 302))
ctx.strokePath()

// Review Nodes / Dots
let dots = [
    CGPoint(x: 835, y: 295),
    CGPoint(x: 925, y: 300),
    CGPoint(x: 1085, y: 302)
]
for pt in dots {
    ctx.setFillColor(warmOchre.cgColor)
    ctx.fillEllipse(in: CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10))
    ctx.setStrokeColor(darkCanvas.cgColor)
    ctx.setLineWidth(2.0)
    ctx.strokeEllipse(in: CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10))
}

// Chart Labels
let chartLabelFont = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .bold)
"MEMORY STABILITY: 94%".draw(at: CGPoint(x: 765, y: 125), withAttributes: [
    .font: chartLabelFont,
    .foregroundColor: recallEasy,
    .kern: 0.5
])
"EXAM READY ✦".draw(at: CGPoint(x: 1005, y: 125), withAttributes: [
    .font: chartLabelFont,
    .foregroundColor: warmOchre,
    .kern: 0.5
])

// Bottom Domain Footer
let domainFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
"kortex-study-app-2026.web.app".draw(at: CGPoint(x: 80, y: 40), withAttributes: [
    .font: domainFont,
    .foregroundColor: mutedSage,
    .kern: 1.0
])

"Drop. Parse. Master.".draw(at: CGPoint(x: 360, y: 40), withAttributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .bold),
    .foregroundColor: textMuted
])

image.unlockFocus()

// Save to destination
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
    print("Failed to convert image to JPEG")
    exit(1)
}

let outputPath = "/Users/protector/Documents/projects/kortex/web_landing/assets/images/social_og.jpg"
do {
    try jpegData.write(to: URL(fileURLWithPath: outputPath))
    print("Successfully wrote \(jpegData.count) bytes to \(outputPath)")
} catch {
    print("Error saving image: \(error)")
    exit(1)
}
