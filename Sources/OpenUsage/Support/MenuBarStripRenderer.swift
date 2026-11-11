import AppKit
import SwiftUI

@MainActor
enum MenuBarStripRenderer {
    static func image(for content: MenuBarContent) -> NSImage? {
        guard !content.isEmpty else { return content.updateAvailable ? appIconWithUpdateDot : nil }
        let renderer = ImageRenderer(content: MenuBarTextStrip(content: content))
        renderer.scale = 2
        guard let rendered = renderer.cgImage else { return nil }
        let cgImage = trimmedToVisibleContent(rendered) ?? rendered
        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: CGFloat(cgImage.width) / renderer.scale, height: CGFloat(cgImage.height) / renderer.scale)
        )
        // A template image lets macOS tint the strip for the menu bar, but drops every colour in it.
        image.isTemplate = !content.isColored
        image.accessibilityDescription = content.accessibilityText
        return image
    }

    static var appIcon: NSImage {
        ProviderMarks.image(for: "openusage", side: 18, inset: 0.08)
    }

    /// The app icon at the same size with a dot in its top-right corner, cut out of the mark so the two
    /// never touch.
    static var appIconWithUpdateDot: NSImage {
        let icon = appIcon
        let image = NSImage(size: icon.size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            icon.draw(in: rect)
            let dot = CGRect(x: rect.maxX - 5, y: rect.maxY - 5, width: 5, height: 5)
            context.setBlendMode(.clear)
            context.fillEllipse(in: dot.insetBy(dx: -1, dy: -1))
            context.setBlendMode(.normal)
            context.setFillColor(.black)
            context.fillEllipse(in: dot)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Update available"
        return image
    }

    nonisolated static func trimmedToVisibleContent(_ image: CGImage) -> CGImage? {
        guard let bounds = visibleBounds(of: image) else { return nil }
        return image.cropping(to: bounds)
    }

    nonisolated static func visibleBounds(of image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        var alpha = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &alpha, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where alpha[row + x] != 0 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}

/// The strip's colours. A template strip is drawn in black for macOS to tint; a coloured one is drawn in the
/// menu bar's own ink, with the severity colours resolved for its appearance.
struct MenuBarPalette {
    let ink: Color
    private let showsSeverity: Bool
    private let appearance: NSAppearance?

    init(for content: MenuBarContent) {
        showsSeverity = content.isColored
        ink = showsSeverity && content.darkMenuBar ? .white : .black
        appearance = NSAppearance(named: content.darkMenuBar ? .darkAqua : .aqua)
    }

    func value(_ severity: WidgetData.MeterSeverity) -> Color {
        color(severity, Theme.severityTextColor(severity))
    }

    func meterFill(_ severity: WidgetData.MeterSeverity) -> Color {
        color(severity, Theme.severityColor(severity))
    }

    private func color(_ severity: WidgetData.MeterSeverity, _ color: Color) -> Color {
        guard showsSeverity, severity != .normal, let appearance else { return ink }
        // System colours resolve against the current drawing appearance, which an offscreen render doesn't share.
        var resolved = NSColor(color).cgColor
        appearance.performAsCurrentDrawingAppearance { resolved = NSColor(color).cgColor }
        return Color(cgColor: resolved)
    }
}

struct MenuBarTextStrip: View {
    let content: MenuBarContent

    private var palette: MenuBarPalette { MenuBarPalette(for: content) }

    var body: some View {
        HStack(spacing: 11) {
            ForEach(content.items) { item in
                HStack(spacing: 4) {
                    glyph(item.provider.icon)
                        .overlay(alignment: .bottomTrailing) {
                            if let badge = item.provider.badge {
                                AccountBadge(text: badge)
                                    .offset(x: AccountBadge.overhang.width, y: AccountBadge.overhang.height)
                            }
                        }
                        .compositingGroup()
                        // The renderer draws only inside layout bounds, so reserve the badge's overhang
                        // (vertically on both sides, keeping the mark centred on its values) or it is cut off.
                        .padding(.trailing, item.provider.badge == nil ? 0 : AccountBadge.overhang.width)
                        .padding(.vertical, item.provider.badge == nil ? 0 : AccountBadge.overhang.height)
                    labelledValue(item)
                    if item.reset != nil || item.meter != nil {
                        resetAndPace(item)
                    }
                }
            }
            if content.overflow > 0 {
                overflowCount(content.overflow)
            }
            if content.updateAvailable {
                Image(nsImage: MenuBarStripRenderer.appIconWithUpdateDot)
                    .renderingMode(.template)
            }
        }
        .foregroundStyle(palette.ink)
        .monospacedDigit()
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .fixedSize()
        .compositingGroup()
    }

    private func labelledValue(_ item: MenuBarContent.Item) -> some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(item.shortLabel)
                .font(.system(size: 9, weight: .medium))
            Text(item.value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(palette.value(item.valueSeverity))
        }
        .fixedSize()
    }

    private func resetAndPace(_ item: MenuBarContent.Item) -> some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(item.reset ?? "")
                .font(.system(size: 9, weight: .medium))
            Group {
                if let meter = item.meter {
                    paceBar(meter)
                } else {
                    Color.clear.frame(width: PaceBar.width, height: PaceBar.markHeight)
                }
            }
            .frame(height: PaceBar.rowHeight)
        }
        .fixedSize()
    }

    private enum PaceBar {
        static let width: CGFloat = 18
        static let height: CGFloat = 3
        static let markWidth: CGFloat = 1.5
        static let markHeight: CGFloat = 7
        static let rowHeight: CGFloat = 13
        static let trackOpacity = 0.3
    }

    private func paceBar(_ meter: MenuBarContent.Meter) -> some View {
        let clamp = { (share: Double) in CGFloat(min(max(share, 0), 1)) }
        return ZStack(alignment: .leading) {
            Capsule().fill(palette.ink.opacity(PaceBar.trackOpacity))
                .frame(width: PaceBar.width, height: PaceBar.height)
            Capsule().fill(palette.meterFill(meter.paceSeverity))
                .frame(width: PaceBar.width * clamp(meter.fill), height: PaceBar.height)
            Rectangle().fill(palette.ink)
                .frame(width: PaceBar.markWidth, height: PaceBar.markHeight)
                .offset(x: (PaceBar.width - PaceBar.markWidth) * clamp(meter.paceMark))
        }
        .frame(width: PaceBar.width, height: PaceBar.markHeight, alignment: .leading)
    }

    private func overflowCount(_ count: Int) -> some View {
        Text("+\(count)")
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(Capsule().fill(palette.ink.opacity(0.16)))
    }

    private static let glyphSide: CGFloat = 16

    private func glyph(_ icon: String) -> some View {
        Image(nsImage: ProviderMarks.image(for: icon, side: Self.glyphSide, inset: 0.04))
            .renderingMode(.template)
            .foregroundStyle(palette.ink)
    }
}
