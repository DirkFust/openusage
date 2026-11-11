import Foundation

struct MenuBarContent: Equatable {
    struct Item: Equatable, Identifiable {
        let id: String
        let provider: Provider
        let label: String
        let shortLabel: String
        let value: String
        /// Colours the value when little is left, at the Priority levels.
        var valueSeverity: WidgetData.MeterSeverity = .normal
        /// The time until the limit resets, like "2h", or nil when it has no reset to show.
        var reset: String?
        /// The small bar beside the value, or nil when the limit has no pace to show.
        var meter: Meter?
    }

    /// How full a limit is, the way its row fills, and where an even pace would have it by now.
    struct Meter: Equatable {
        let fill: Double
        let paceMark: Double
        let paceSeverity: WidgetData.MeterSeverity
    }

    let items: [Item]
    var overflow = 0
    var updateAvailable = false
    /// The strip draws its own colours once anything is coloured, so it has to know the menu bar's appearance.
    var darkMenuBar = false

    var isEmpty: Bool { items.isEmpty }

    var isColored: Bool {
        items.contains { $0.valueSeverity != .normal || ($0.meter.map { $0.paceSeverity != .normal } ?? false) }
    }

    var accessibilityText: String {
        let shown = items.map { "\($0.provider.fullName) \($0.label) \($0.value)" }
        let more = overflow > 0 ? ["\(overflow) more"] : []
        let update = updateAvailable ? ["Update available"] : []
        return (shown + more + update).joined(separator: "; ")
    }
}

@MainActor
enum MenuBarContentBuilder {
    private static let genericWords: Set<String> = ["models", "bot", "usage"]

    /// Only what's running out, or with `alwaysShows` every section of the Priority tab in its order, top to bottom.
    static func build(board: PriorityBoard, limit: MenuBarLimit, alwaysShows: Bool = false, now: Date = Date()) -> MenuBarContent {
        guard limit != .iconOnly else { return MenuBarContent(items: []) }
        let counted = alwaysShows
            ? board.pinned.map { ($0.provider, $0.line) } + (board.attention + board.useItOrLoseIt).map { ($0.provider, $0.line) }
            : board.runningOut.map { ($0.provider, $0.line) }
        let usedUp = alwaysShows ? board.usedUp.map { ($0.provider, $0.line) } : []
        let shown = (counted + usedUp).prefix(limit.count).map { provider, line in
            let label = line.data.title
            return MenuBarContent.Item(
                id: line.id,
                provider: provider,
                label: label,
                shortLabel: shortLabel(label),
                value: line.data.menuBarValue,
                valueSeverity: line.data.severity,
                reset: line.data.menuBarReset(now: now),
                meter: line.data.menuBarMeter(now: now)
            )
        }
        return MenuBarContent(items: shown, overflow: max(0, counted.count - shown.count))
    }

    static func shortLabel(_ label: String) -> String {
        var words = label.split(separator: " ")
        guard words.count > 1, let last = words.last, genericWords.contains(last.lowercased()) else { return label }
        words.removeLast()
        return words.joined(separator: " ")
    }
}

extension WidgetData {
    /// The time until the reset in one coarse unit, or nil without a reset or before the session started.
    func menuBarReset(now: Date) -> String? {
        guard hasData, let resetsAt, !isFreshSessionWindow(now: now) else { return nil }
        return Formatters.coarseDuration(resetsAt.timeIntervalSince(now))
    }

    /// The fill and pace mark of the limit's row, coloured by where its pace lands at the reset.
    func menuBarMeter(now: Date) -> MenuBarContent.Meter? {
        guard let paceMark = paceMark(now: now) else { return nil }
        return MenuBarContent.Meter(fill: fraction, paceMark: paceMark, paceSeverity: paceSeverity(now: now))
    }

    private func paceSeverity(now: Date) -> MeterSeverity {
        switch meterState(now: now) {
        case .runningOut: .critical
        case .closeToLimit: .warning
        case .healthy, .unpaced, .spent, .noData: .normal
        }
    }
}
