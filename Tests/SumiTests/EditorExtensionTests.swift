import Foundation
import XCTest
@testable import Sumi

/// The VS Code and Nova extensions ship with each release, so their manifests
/// must carry the release version and the `.sumi` language.
final class EditorExtensionTests: XCTestCase {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func testVSCodeExtensionMatchesTheSumiVersionAndLanguage() throws {
        let manifest = try json("editors/vscode/package.json")
        XCTAssertEqual(manifest["version"] as? String, SumiMetadata.currentVersion)
        let contributes = try XCTUnwrap(manifest["contributes"] as? [String: Any])
        let language = try XCTUnwrap((contributes["languages"] as? [[String: Any]])?.first)
        XCTAssertEqual(language["id"] as? String, "sumi")
        XCTAssertEqual(language["extensions"] as? [String], [".sumi"])
        for entry in (contributes["grammars"] as? [[String: Any]] ?? []) + (contributes["snippets"] as? [[String: Any]] ?? []) {
            let path = try XCTUnwrap(entry["path"] as? String)
            XCTAssertTrue(FileManager.default.fileExists(atPath: Self.root.appendingPathComponent("editors/vscode").appendingPathComponent(path).path), path)
        }
    }

    func testNovaExtensionMatchesTheSumiVersionAndLanguage() throws {
        let manifest = try json("editors/nova/Sumi.novaextension/extension.json")
        XCTAssertEqual(manifest["version"] as? String, SumiMetadata.currentVersion)
        XCTAssertTrue((manifest["activationEvents"] as? [String] ?? []).contains("onLanguage:sumi"))
        let syntax = try String(contentsOf: Self.root.appendingPathComponent("editors/nova/Sumi.novaextension/Syntaxes/Sumi.xml"), encoding: .utf8)
        XCTAssertTrue(syntax.contains(#"<syntax name="sumi""#))
        XCTAssertTrue(syntax.contains("<extension priority=\"1.0\">sumi</extension>"))
    }

    private func json(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: Self.root.appendingPathComponent(path))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
