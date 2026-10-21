import XCTest
@testable import TimeTrackerCore

final class OverlapEngineTests: XCTestCase {

    private func makeCheck(tz: String, schedule: [String: [HourRange]]) -> Check {
        Check(name: "Test", timeZoneIdentifier: tz, schedule: schedule)
    }

    private func schedule(_ overrides: [String: [HourRange]]) -> [String: [HourRange]] {
        var d = Check.emptySchedule
        for (k, v) in overrides { d[k] = v }
        return d
    }

    private func makeDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, in tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    // 2026-10-19 = Monday; weekdays follow through 10-25 = Sunday.

    func testOverlapWithinWorkingHours() {
        let check = makeCheck(tz: "Asia/Tokyo", schedule: schedule(["mon": [HourRange(start: "09:00", end: "17:00")]]))
        let now = makeDate(2026, 10, 19, 10, 0, in: tokyo)
        let state = OverlapEngine.evaluate(check: check, now: now)
        XCTAssertTrue(state.isOverlapping)
        XCTAssertEqual(state.activeRange, HourRange(start: "09:00", end: "17:00"))
    }

    func testNoOverlapOutsideHours() {
        let check = makeCheck(tz: "Asia/Tokyo", schedule: schedule(["mon": [HourRange(start: "09:00", end: "17:00")]]))
        let now = makeDate(2026, 10, 19, 20, 0, in: tokyo)
        XCTAssertFalse(OverlapEngine.evaluate(check: check, now: now).isOverlapping)
    }

    func testStartInclusiveEndExclusive() {
        let check = makeCheck(tz: "Asia/Tokyo", schedule: schedule(["mon": [HourRange(start: "09:00", end: "17:00")]]))
        XCTAssertTrue(OverlapEngine.evaluate(check: check, now: makeDate(2026, 10, 19, 9, 0, in: tokyo)).isOverlapping)
        XCTAssertFalse(OverlapEngine.evaluate(check: check, now: makeDate(2026, 10, 19, 17, 0, in: tokyo)).isOverlapping)
    }

    func testOffDayNoOverlap() {
        let check = makeCheck(tz: "Asia/Tokyo", schedule: schedule(["mon": [HourRange(start: "09:00", end: "17:00")]]))
        let sunday = makeDate(2026, 10, 25, 10, 0, in: tokyo)
        XCTAssertFalse(OverlapEngine.evaluate(check: check, now: sunday).isOverlapping)
    }

    func testOvernightRange() {
        let check = makeCheck(tz: "Asia/Tokyo", schedule: schedule(["fri": [HourRange(start: "22:00", end: "06:00")]]))
        // Friday 23:00 — inside Friday's overnight band.
        XCTAssertTrue(OverlapEngine.evaluate(check: check, now: makeDate(2026, 10, 23, 23, 0, in: tokyo)).isOverlapping)
        // Saturday 03:00 — reached via Friday's overnight spillover.
        XCTAssertTrue(OverlapEngine.evaluate(check: check, now: makeDate(2026, 10, 24, 3, 0, in: tokyo)).isOverlapping)
        // Saturday 07:00 — after the band ends.
        XCTAssertFalse(OverlapEngine.evaluate(check: check, now: makeDate(2026, 10, 24, 7, 0, in: tokyo)).isOverlapping)
    }

    func testNonContiguousRanges() {
        let check = makeCheck(tz: "Asia/Tokyo", schedule: schedule(["mon": [
            HourRange(start: "09:00", end: "12:00"),
            HourRange(start: "14:00", end: "18:00"),
        ]]))
        XCTAssertFalse(OverlapEngine.evaluate(check: check, now: makeDate(2026, 10, 19, 13, 0, in: tokyo)).isOverlapping)
        XCTAssertTrue(OverlapEngine.evaluate(check: check, now: makeDate(2026, 10, 19, 15, 0, in: tokyo)).isOverlapping)
    }
}
