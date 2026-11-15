import Foundation
import XCTest
@testable import Sumi

final class MCPServerTests: XCTestCase {
    func testInitializeNamesSumiAndItsVersion() throws {
        let response = try XCTUnwrap(MCPServer.respond(to: ["jsonrpc": "2.0", "id": 1, "method": "initialize"], root: URL(fileURLWithPath: "/")))
        let info = try XCTUnwrap((response["result"] as? [String: Any])?["serverInfo"] as? [String: Any])
        XCTAssertEqual(info["name"] as? String, "sumi")
        XCTAssertEqual(info["version"] as? String, SumiMetadata.currentVersion)
    }

    func testNotificationsGetNoReplyAndUnknownMethodsAnError() {
        XCTAssertNil(MCPServer.respond(to: ["jsonrpc": "2.0", "method": "notifications/initialized"], root: URL(fileURLWithPath: "/")))
        let response = MCPServer.respond(to: ["jsonrpc": "2.0", "id": 2, "method": "resources/list"], root: URL(fileURLWithPath: "/"))
        XCTAssertEqual((response?["error"] as? [String: Any])?["code"] as? Int, -32601)
    }

    func testListsTheThreeTools() throws {
        let response = try XCTUnwrap(MCPServer.respond(to: ["jsonrpc": "2.0", "id": 3, "method": "tools/list"], root: URL(fileURLWithPath: "/")))
        let tools = try XCTUnwrap((response["result"] as? [String: Any])?["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.compactMap { $0["name"] as? String }, ["docs_page", "search_docs", "site_info"])
    }

    func testServesTheEmbeddedGuides() {
        XCTAssertTrue(MCPServer.pageNames.contains("templates/syntax"))
        XCTAssertTrue(MCPServer.pageNames.contains("deployment"))
        XCTAssertFalse(MCPServer.pageNames.contains("upgrading/next"))
        XCTAssertTrue(MCPServer.docsPage("templates/syntax").hasPrefix("# Syntax"))
        XCTAssertTrue(MCPServer.docsPage("deployment").hasPrefix("# "))
        XCTAssertTrue(MCPServer.docsPage("nope").contains("Unknown page 'nope'"))
        XCTAssertTrue(MCPServer.searchDocs(query: "optional binding").contains("docs/templates/syntax.md"))
        XCTAssertEqual(MCPServer.searchDocs(query: "zzqqxx"), "No docs matched 'zzqqxx'.")
    }

    func testSiteInfoReadsTheSiteConfig() throws {
        let site = try TemporaryDirectory()
        XCTAssertTrue(MCPServer.siteInfo(root: site.url).contains("No sumi.json here"))
        try #"{ "site": { "title": "Mine" } }"#.write(to: site.url.appendingPathComponent("sumi.json"), atomically: true, encoding: .utf8)
        XCTAssertTrue(MCPServer.siteInfo(root: site.url).contains(#""title": "Mine""#))
    }
}
