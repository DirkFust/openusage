import XCTest
@testable import OpenUsage

@MainActor
final class MenuBarResetPaceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let personal = Provider(id: "claude@1", kind: .claude, accountLabel: "Personal")
    private let fiveHours: TimeInterval = 5 * 60 * 60

    private func session(used: Double, resetsIn: TimeInterval?, displayMode: WidgetDisplayMode = .used) -> WidgetData {
        var data = WidgetData(title: "Session", kind: .percent, used: used, limit: 100)
        data.displayMode = displayMode
        data.resetsAt = resetsIn.map { now.addingTimeInterval($0) }
        data.periodDurationMs = Int(fiveHours * 1_000)
        return data
    }

    private func pinnedItem(_ data: WidgetData) throws -> MenuBarContent.Item {
        let line = DashboardLine(
            descriptor: WidgetDescriptor(provider: personal, key: data.title, metricLabel: data.title, sample: data),
            data: data
        )
        let board = PriorityBoard.make(
            accounts: [DashboardAccount(provider: personal, lines: [line])], pinned: ["claude@1.Session"], now: now
        )
        return try XCTUnwrap(MenuBarContentBuilder.build(board: board, limit: .upToOne, alwaysShows: true, now: now).items.first)
    }

    func testTheResetShowsInOneCoarseUnit() {
        let cases: [(TimeInterval, String)] = [
            (30, "1m"), (22 * 60, "22m"), (59 * 60 + 30, "1h"), (2 * 3600 + 40 * 60, "2h"),
            (23 * 3600 + 59 * 60, "23h"), (24 * 3600, "1d"), (3 * 86_400 + 20 * 3600, "3d"),
        ]
        for (seconds, text) in cases {
            XCTAssertEqual(Formatters.coarseDuration(seconds), text, "\(seconds)s")
        }
        XCTAssertNil(Formatters.coarseDuration(0))
        XCTAssertNil(Formatters.coarseDuration(-5))
    }

    func testALimitBurningFasterThanItsWindowShowsItsResetAndARedPaceBar() throws {
        // 3 of 5 hours gone with 65% used: an even pace would be at 60%, so this runs out before the reset.
        let item = try pinnedItem(session(used: 65, resetsIn: 2 * 3600))

        XCTAssertEqual(item.reset, "2h")
        let meter = try XCTUnwrap(item.meter)
        XCTAssertEqual(meter.fill, 0.65, accuracy: 0.001)
        XCTAssertEqual(meter.paceMark, 0.6, accuracy: 0.001)
        XCTAssertEqual(meter.paceSeverity, .critical)
        XCTAssertEqual(item.valueSeverity, .normal, "35% left is above the warning level")
    }

    func testALimitCloseToItsLimitAtResetShowsAnOrangePaceBar() throws {
        // 2.5 of 5 hours gone with 48% used lands at 96% by the reset.
        let item = try pinnedItem(session(used: 48, resetsIn: 2.5 * 3600))
        XCTAssertEqual(item.meter?.paceSeverity, .warning)
    }

    func testALimitWithRoomToSpareKeepsItsPaceBarUncoloured() throws {
        let item = try pinnedItem(session(used: 20, resetsIn: 2 * 3600))
        XCTAssertEqual(item.meter?.paceSeverity, .normal)
        XCTAssertFalse(MenuBarContent(items: [item]).isColored)
    }

    func testTheValueTakesThePriorityColourWhenLittleIsLeft() throws {
        XCTAssertEqual(try pinnedItem(session(used: 75, resetsIn: 30 * 60)).valueSeverity, .warning)
        XCTAssertEqual(try pinnedItem(session(used: 95, resetsIn: 30 * 60)).valueSeverity, .critical)
    }

    func testTheBarFollowsTheLeftReadingWhenTheLimitShowsWhatsLeft() throws {
        let item = try pinnedItem(session(used: 70, resetsIn: 2 * 3600, displayMode: .remaining))
        let meter = try XCTUnwrap(item.meter)
        XCTAssertEqual(meter.fill, 0.3, accuracy: 0.001)
        XCTAssertEqual(meter.paceMark, 0.4, accuracy: 0.001)
    }

    func testALimitWithoutAResetShowsNeitherResetNorBar() throws {
        let item = try pinnedItem(session(used: 40, resetsIn: nil))
        XCTAssertNil(item.reset)
        XCTAssertNil(item.meter)
    }

    func testAUsedUpLimitShowsItsResetButNoBar() throws {
        let item = try pinnedItem(session(used: 100, resetsIn: 40 * 60))
        XCTAssertEqual(item.reset, "40m")
        XCTAssertNil(item.meter, "a used-up limit has no pace to show")
        XCTAssertEqual(item.valueSeverity, .critical)
    }

    func testOnlyAColouredStripLeavesTheTemplateLook() throws {
        let calm = MenuBarContent(items: [try pinnedItem(session(used: 20, resetsIn: 2 * 3600))])
        let hot = MenuBarContent(items: [try pinnedItem(session(used: 70, resetsIn: 2 * 3600))])

        XCTAssertTrue(try XCTUnwrap(MenuBarStripRenderer.image(for: calm)).isTemplate)
        XCTAssertFalse(try XCTUnwrap(MenuBarStripRenderer.image(for: hot)).isTemplate)
    }

    func testTheStripRedrawsWhenTheMenuBarTurnsDark() throws {
        var shown: [MenuBarContent] = []
        var gate = StatusItemController.StripGate()
        let light = MenuBarContent(items: [try pinnedItem(session(used: 70, resetsIn: 2 * 3600))])
        var dark = light
        dark.darkMenuBar = true

        gate.show(light, using: { shown.append($0) })
        gate.show(dark, using: { shown.append($0) })
        XCTAssertEqual(shown, [light, dark])
    }
}
