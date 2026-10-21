import XCTest
@testable import TimeTrackerCore

final class CheckStoreTests: XCTestCase {

    private func schedule(_ overrides: [String: [HourRange]]) -> [String: [HourRange]] {
        var d = Check.emptySchedule
        for (k, v) in overrides { d[k] = v }
        return d
    }

    func testCodableRoundTrip() throws {
        let check = Check(
            name: "Tokyo",
            timeZoneIdentifier: "Asia/Tokyo",
            schedule: schedule([
                "mon": [HourRange(start: "09:00", end: "12:00"), HourRange(start: "14:00", end: "18:00")],
                "fri": [HourRange(start: "22:00", end: "06:00")],
            ])
        )
        let file = ChecksFile(checks: [check])
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ChecksFile.self, from: data)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.checks, [check])
    }

    @MainActor
    func testStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("checks.json")

        let check = Check(name: "Tokyo", timeZoneIdentifier: "Asia/Tokyo", schedule: schedule(["mon": [HourRange(start: "09:00", end: "17:00")]]))

        let store = CheckStore(fileURL: url)
        store.add(check)
        XCTAssertEqual(store.checks, [check])

        let reloaded = CheckStore(fileURL: url)
        XCTAssertEqual(reloaded.checks, [check])

        reloaded.remove(id: check.id)
        XCTAssertTrue(reloaded.checks.isEmpty)

        let reloadedAgain = CheckStore(fileURL: url)
        XCTAssertTrue(reloadedAgain.checks.isEmpty)
    }
}
