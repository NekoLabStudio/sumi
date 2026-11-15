import XCTest
@testable import Sumi

final class ThemeEjectTests: XCTestCase {
    func testCopiesDefaultSumiTemplatesWithoutOverwritingExistingFiles() throws {
        let root = try TemporaryDirectory()
        try FileManager.default.createDirectory(at: root.url.appendingPathComponent("theme/pages"), withIntermediateDirectories: true)
        try "Custom home".write(to: root.url.appendingPathComponent("theme/pages/home.sumi"), atomically: true, encoding: .utf8)

        let result = try ThemeEjector.eject(root: root.url)

        XCTAssertTrue(result.copied.contains("theme/layouts/default.sumi"))
        XCTAssertTrue(result.copied.contains("theme/pages/feed.xml.sumi"))
        XCTAssertTrue(result.copied.contains("theme/pages/feed.json.sumi"))
        XCTAssertTrue(result.copied.contains("theme/pages/post.sumi"))
        XCTAssertTrue(result.copied.contains("theme/pages/404.sumi"))
        XCTAssertTrue(result.skipped.contains("theme/pages/home.sumi"))
        XCTAssertEqual(try String(contentsOf: root.url.appendingPathComponent("theme/pages/home.sumi"), encoding: .utf8), "Custom home")

        let forced = try ThemeEjector.eject(root: root.url, force: true)
        XCTAssertTrue(forced.copied.contains("theme/pages/home.sumi"))
        XCTAssertTrue(forced.copied.contains("theme/components/PostList.sumi"))
        XCTAssertTrue(try String(contentsOf: root.url.appendingPathComponent("theme/components/PostList.sumi"), encoding: .utf8).contains("post-list"))
    }

    func testEjectDoesNotShadowExistingFlatTemplates() throws {
        let root = try TemporaryDirectory()
        try FileManager.default.createDirectory(at: root.url.appendingPathComponent("theme"), withIntermediateDirectories: true)
        try "Flat custom home".write(to: root.url.appendingPathComponent("theme/home.sumi"), atomically: true, encoding: .utf8)

        let result = try ThemeEjector.eject(root: root.url)

        XCTAssertTrue(result.skipped.contains("theme/pages/home.sumi"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.url.appendingPathComponent("theme/pages/home.sumi").path))
        XCTAssertEqual(try String(contentsOf: root.url.appendingPathComponent("theme/home.sumi"), encoding: .utf8), "Flat custom home")
    }

    func testCanEjectIntoConfiguredThemePath() throws {
        let root = try TemporaryDirectory()

        let result = try ThemeEjector.eject(root: root.url, themePath: "custom-theme")

        XCTAssertTrue(result.copied.contains("custom-theme/layouts/default.sumi"))
        XCTAssertTrue(result.copied.contains("custom-theme/components/SiteStyles.sumi"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.url.appendingPathComponent("custom-theme/layouts/default.sumi").path))
    }
}
