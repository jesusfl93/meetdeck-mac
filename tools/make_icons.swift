// Genera los iconos PNG 144x144 con SF Symbols.
//   swift tools/make_icons.swift            → icons/ (botones) y plugin/…/imgs/ (estados del plugin)
// Se generan en cada Mac (no se versionan): la licencia de SF Symbols no permite redistribuirlos.

import AppKit

let blue = NSColor(red: 0.10, green: 0.45, blue: 0.91, alpha: 1)
let gray = NSColor(white: 0.45, alpha: 1)
let red = NSColor(red: 0.92, green: 0.20, blue: 0.20, alpha: 1)

func render(_ path: String, symbol: String, label: String, color: NSColor,
            slashed: Bool = false, labelColor: NSColor = .white, size: Int = 144) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(size) / 144

    NSColor(white: 0.08, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let config = NSImage.SymbolConfiguration(pointSize: 56 * scale, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    let s = image.size
    let box = NSRect(x: (CGFloat(size) - s.width) / 2, y: (58 + (66 - s.height / scale) / 2) * scale,
                     width: s.width, height: s.height)
    image.draw(in: box)

    if slashed {
        // Línea roja diagonal con borde del color de fondo para que se lea sobre el símbolo.
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 38 * scale, y: 128 * scale))
        line.line(to: NSPoint(x: 106 * scale, y: 56 * scale))
        line.lineCapStyle = .round
        NSColor(white: 0.08, alpha: 1).setStroke()
        line.lineWidth = 16 * scale
        line.stroke()
        red.setStroke()
        line.lineWidth = 8 * scale
        line.stroke()
    }

    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 20 * scale, weight: .bold),
        .foregroundColor: labelColor,
        .paragraphStyle: style,
    ]
    (label as NSString).draw(in: NSRect(x: 0, y: 18 * scale, width: CGFloat(size), height: 28 * scale), withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("OK \(path)")
}

let imgs = "plugin/com.fluentdata.meet.sdPlugin/imgs"
for dir in ["icons", imgs] {
    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
}

// Botones fijos (Open Application)
let icons: [(name: String, symbol: String, label: String, color: NSColor)] = [
    ("MeetMic", "mic.fill", "MIC", blue),
    ("MeetCam", "video.fill", "CÁMARA", blue),
    ("MeetHand", "hand.raised.fill", "MANO", blue),
    ("MeetFocus", "macwindow", "IR A MEET", blue),
    ("MeetChat", "message.fill", "CHAT", blue),
    ("MeetFolder", "video.fill", "MEET", NSColor(red: 0.00, green: 0.60, blue: 0.45, alpha: 1)),
    ("AudioHeadset", "headphones", "HEADSET", NSColor(red: 0.18, green: 0.60, blue: 0.36, alpha: 1)),
    ("AudioSpeakers", "laptopcomputer", "BOCINAS", NSColor(red: 0.85, green: 0.47, blue: 0.13, alpha: 1)),
]
for icon in icons {
    render("icons/\(icon.name).png", symbol: icon.symbol, label: icon.label, color: icon.color)
}

// Estados del plugin: on = abierto, off = cerrado (línea roja), idle = sin reunión
for (key, symbol, label) in [("mic", "mic.fill", "MIC"), ("cam", "video.fill", "CÁMARA")] {
    render("\(imgs)/\(key)-on.png", symbol: symbol, label: label, color: blue)
    render("\(imgs)/\(key)-off.png", symbol: symbol, label: label, color: NSColor(white: 0.85, alpha: 1), slashed: true, labelColor: red)
    render("\(imgs)/\(key)-idle.png", symbol: symbol, label: label, color: gray, labelColor: gray)
}
render("\(imgs)/plugin.png", symbol: "video.fill", label: "MEET", color: blue, size: 288)
render("\(imgs)/category.png", symbol: "video.fill", label: "", color: .white, size: 56)
