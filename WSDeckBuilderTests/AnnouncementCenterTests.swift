import XCTest
@testable import WSDeckBuilder

@MainActor
final class AnnouncementCenterTests: XCTestCase {
    func testDuplicateSourcesAndIndividualReadStatePersist() throws {
        let suite = "notification-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = Announcement(id: "data-update-A-2", date: "2026-09-11", title: "新系列", body: "可下載")
        let second = Announcement(id: "manual", date: "2026-09-11", title: "手動公告", body: "內容")
        defaults.set(try JSONEncoder().encode([first, second]), forKey: "announcement.cachedItems")
        defaults.set(try JSONEncoder().encode([first]), forKey: "announcement.localItems")
        let center = AnnouncementCenter(defaults: defaults)
        XCTAssertEqual(center.items.count, 2)
        XCTAssertEqual(center.unreadCount, 2)
        center.markRead(first)
        XCTAssertEqual(center.unreadCount, 1)
        XCTAssertEqual(AnnouncementCenter(defaults: defaults).unreadCount, 1)
        center.delete(first)
        XCTAssertEqual(AnnouncementCenter(defaults: defaults).items.map(\.id), ["manual"])
    }

    func testLegacyUpdatesKeepNewestVersionPerSeries() {
        let items = [2, 10, 3].map { Announcement(id: "data-update-A-B-\($0)", date: "2026-09-11", title: "更新", body: "內容") }
        XCTAssertEqual(AnnouncementCenter.compactLocalItems(items).map(\.id), ["data-update-A-B-10"])
    }
}
