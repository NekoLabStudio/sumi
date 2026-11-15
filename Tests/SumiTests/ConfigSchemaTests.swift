import Foundation
import XCTest
@testable import Sumi

final class ConfigSchemaTests: XCTestCase {
    private var schemaURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("support/sumi.schema.json")
    }

    func testSchemaDeclaresEveryConfigKey() throws {
        let schema = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL)) as? [String: Any])
        XCTAssertEqual(schema["$id"] as? String, SumiMetadata.configSchemaURL)
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let declared = Set(SumiConfig.CodingKeys.allCases.map(\.stringValue))
        XCTAssertEqual(declared.subtracting(properties.keys), [])
        XCTAssertEqual(Set(properties.keys).subtracting(declared), [])
    }

    func testGeneratedConfigPointsAtSchemaAndStillDecodes() throws {
        let parent = try TemporaryDirectory()
        let site = parent.url.appendingPathComponent("site")
        _ = try SiteInitializer.initSite(at: site, options: InitSiteOptions(ci: nil, deploy: nil, syndication: []))

        let text = try String(contentsOf: site.appendingPathComponent(SumiMetadata.configFileName), encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("{\n  \"$schema\" : "), text)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertEqual(json["$schema"] as? String, SumiMetadata.configSchemaURL)
        XCTAssertNoThrow(try ConfigLoader.load(root: site))
    }
}
