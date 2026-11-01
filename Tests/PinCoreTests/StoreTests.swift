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

    func testFlowsNeedRealBoardsAndDoNotRepeat() throws {
        try store.addVersion(app: "10", name: "Today", picture: picture)
        try store.addVersion(app: "10", name: "Train", picture: picture)
        try store.addFlow(app: "10", from: "today", to: "train", label: "Arrow")
        try store.addFlow(app: "10", from: "today", to: "train", label: "Next")
        XCTAssertEqual(try store.flows(app: "10"), [FlowEdge(from: "today", to: "train", label: "Next")])
        XCTAssertThrowsError(try store.addFlow(app: "10", from: "today", to: "nope"))
        XCTAssertThrowsError(try store.addFlow(app: "10", from: "today", to: "today"))
        try store.removeFlow(app: "10", from: "today", to: "train")
        XCTAssertEqual(try store.flows(app: "10"), [])
    }

    func testBoardPositionsAreKept() throws {
        try store.addVersion(app: "10", name: "Today", picture: picture)
        try store.setPosition(app: "10", screen: "today", x: 12, y: -30)
        XCTAssertEqual(try store.positions(app: "10"), ["today": [12, -30]])
        XCTAssertThrowsError(try store.setPosition(app: "10", screen: "nope", x: 0, y: 0))
    }

    func testSlug() {
        XCTAssertEqual(Store.slug("Today · Good"), "today-good")
    }

    func testLiveConfigKeepsOldFilesAndAllowsABoardItsOwnSize() throws {
        let old = #"{"library":"x","size":{"width":393,"height":852},"boards":{"today":"Today"}}"#
        let plain = try JSONDecoder().decode(LiveConfig.self, from: Data(old.utf8))
        XCTAssertEqual(plain.size(of: "today").height, 852)
        let tall = #"{"library":"x","size":{"width":393,"height":852},"sizes":{"run":{"width":393,"height":1105}},"boards":{"run":"Saved run"}}"#
        let config = try JSONDecoder().decode(LiveConfig.self, from: Data(tall.utf8))
        XCTAssertEqual(config.size(of: "run").height, 1105)
        XCTAssertEqual(config.size(of: "other").height, 852)
    }

    func testWebBoardsAreReadAlongsideOldFieldsAndOnlyLocalPagesRun() throws {
        let file = #"""
        {"web":{"home":{"url":"http://localhost:3000/","width":1280,"height":800},
                "page":{"url":"file:///tmp/a.html","width":390,"height":844,"persistent":true},
                "away":{"url":"https://example.com/","width":100,"height":100},
                "near":{"url":"http://localhost.example.com/","width":100,"height":100},
                "flat":{"url":"http://localhost:3000/","width":0,"height":100}}}
        """#
        let config = try JSONDecoder().decode(LiveConfig.self, from: Data(file.utf8))
        XCTAssertEqual(config.boards, [:])
        XCTAssertEqual(config.size(of: "home").width, 1280)
        XCTAssertEqual(config.size(of: "page").height, 844)
        XCTAssertEqual(config.webBoard("page")?.persistent, true)
        XCTAssertNil(config.webBoard("home")?.persistent)
        for refused in ["away", "near", "flat", "missing"] { XCTAssertNil(config.webBoard(refused), refused) }
        XCTAssertTrue(config.hasWeb)
        let old = #"{"library":"x","size":{"width":393,"height":852},"boards":{"today":"Today"}}"#
        let plain = try JSONDecoder().decode(LiveConfig.self, from: Data(old.utf8))
        XCTAssertFalse(plain.hasWeb)
        XCTAssertEqual(plain.library, "x")
        XCTAssertEqual(plain.boards, ["today": "Today"])
    }
}
