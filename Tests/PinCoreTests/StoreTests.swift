import XCTest
@testable import PinCore

final class StoreTests: XCTestCase {
    private var store: Store!
    private var picture: URL!
    private var temp: URL!

    override func setUpWithError() throws {
        temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        store = Store(home: temp.appendingPathComponent("home"))
        picture = temp.appendingPathComponent("p.png")
        // Smallest valid PNG: one pixel.
        let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
        try XCTUnwrap(Data(base64Encoded: png)).write(to: picture)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: temp) }

    func testVersionsCountUpAndKeepTheirOwnComments() throws {
        try store.addVersion(app: "10", name: "Today", picture: picture, kind: .iphone)
        let first = try store.addThread(app: "10", screen: "today", version: 1, x: 0.5, y: 0.25, text: "bigger", author: "Damian")
        let (screen, second) = try store.addVersion(app: "10", name: "Today", picture: picture, note: "bigger now")
        XCTAssertEqual(second.n, 2)
        XCTAssertEqual(screen.versions.map(\.n), [1, 2])
        let all = try store.threads(app: "10", screen: "today")
        XCTAssertEqual(all.filter { $0.version == 1 }.map(\.id), [first.id])
        XCTAssertTrue(all.filter { $0.version == 2 }.isEmpty)
    }

    func testReplyAndResolveFindTheThreadById() throws {
        try store.addVersion(app: "10", name: "Today", picture: picture)
        let t = try store.addThread(app: "10", screen: "today", version: 1, x: 0, y: 1, text: "hi", author: "Damian")
        try store.reply(thread: t.id, text: "Done: bigger", author: "Claude")
        let resolved = try store.setResolved(thread: t.id, true)
        XCTAssertTrue(resolved.resolved)
        XCTAssertEqual(try store.thread(id: t.id).messages.map(\.author), ["Damian", "Claude"])
    }

    func testRefusesBadInput() throws {
        XCTAssertThrowsError(try store.addVersion(app: "10", name: "Today", picture: temp.appendingPathComponent("none.png")))
        try store.addVersion(app: "10", name: "Today", picture: picture, kind: .iphone)
        XCTAssertThrowsError(try store.addVersion(app: "10", name: "Today", picture: picture, kind: .mac))
        XCTAssertThrowsError(try store.addVersion(app: "../x", name: "Today", picture: picture))
        XCTAssertThrowsError(try store.addThread(app: "10", screen: "today", version: 9, x: 0, y: 0, text: "x", author: "D"))
        XCTAssertThrowsError(try store.addThread(app: "10", screen: "today", version: 1, x: 2, y: 0, text: "x", author: "D"))
        XCTAssertThrowsError(try store.addThread(app: "10", screen: "today", version: 1, x: 0, y: 0, text: "  ", author: "D"))
    }

    func testSlug() {
        XCTAssertEqual(Store.slug("Today · Good"), "today-good")
    }
}
