import XCTest
@testable import Sumi

/// Moving an Inkstead Writer site to Sumi. The fixture is a site created by
/// Inkstead Writer 2.3.1 (`init --ci github-actions --deploy github-pages`,
/// then `theme eject`), with the footer credit turned off in its config and a
/// custom component and script that use the template runtime's names.
final class SumiMigrationTests: XCTestCase {
    static let fixture = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/InksteadWriterSite")

    static let customComponent = """
        @component Toggle(label: String) {
          @script "../scripts/site.js"
          <button data-sumi-track class="sumi-progress-bar">{label}</button>
          @comment { Rendered inside layouts/default.sumi. }
        }

        """

    static let customScript = """
        document.addEventListener("sumi:navigate", function () {
          document.querySelectorAll("[data-sumi-on-click]").forEach(function (node) {
            node.dataset.sumiTracked = "true";
          });
          window.Sumi.progress.done();
        });
        Sumi.visit("/");

        """

    func testMovesAnInksteadWriterSiteToExactlyWhatAFreshSumiSiteLooksLike() throws {
        let site = try oldSite()
        _ = try SumiMigration.run(root: site.url)

        let fresh = try TemporaryDirectory()
        _ = try SiteInitializer.initSite(at: fresh.url, options: InitSiteOptions(ci: .githubActions, deploy: .githubPages))
        _ = try ThemeEjector.eject(root: fresh.url)
        try Self.customComponent.write(to: fresh.url.appendingPathComponent("theme/components/Toggle.sumi"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: fresh.url.appendingPathComponent("theme/scripts"), withIntermediateDirectories: true)
        try Self.customScript.write(to: fresh.url.appendingPathComponent("theme/scripts/site.js"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try snapshot(site.url), try snapshot(fresh.url))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: site.url.appendingPathComponent(SiteWrapper.path).path))
    }

    func testSummarisesEveryRenameAndConfigChange() throws {
        let site = try oldSite()
        let summary = try SumiMigration.run(root: site.url)

        XCTAssertTrue(summary.contains("Renamed inkstead-writer -> sumi"))
        XCTAssertTrue(summary.contains("Renamed inkstead-writer.json -> sumi.json"))
        XCTAssertTrue(summary.contains("Renamed theme/pages/home.plume -> theme/pages/home.sumi"))
        XCTAssertTrue(summary.contains("Updated theme/components/Toggle.sumi: Sumi runtime names"))
        XCTAssertTrue(summary.contains("Updated theme/scripts/site.js: Sumi runtime names"))
        XCTAssertTrue(summary.contains("Updated README.md"))
        XCTAssertTrue(summary.contains("Changed $schema: none -> \(SumiMetadata.configSchemaURL)"))
        XCTAssertTrue(summary.contains("Updated .github/workflows/publish.yml"))
        XCTAssertTrue(summary.contains("Removed theme.showPoweredBy"))
        XCTAssertTrue(summary.contains("Updated theme/components/SiteFooter.sumi: Sumi's default, without the footer credit"))
        XCTAssertTrue(summary.contains("Updated theme/components/SiteStyles.sumi: Sumi's default, without the footer credit"))
        XCTAssertFalse(summary.contains { $0.hasPrefix("Check ") })
        XCTAssertEqual(summary.filter { $0.hasPrefix("Renamed theme/") }.count, 17)
    }

    func testRecordsTheCurrentVersion() throws {
        let site = try oldSite()
        let config = site.url.appendingPathComponent("inkstead-writer.json")
        let old = try String(contentsOf: config, encoding: .utf8)
        try old.replacingOccurrences(of: "\"version\" : \"2.3.1\"", with: "\"version\" : \"2.2.1\"")
            .write(to: config, atomically: true, encoding: .utf8)

        let summary = try SumiMigration.run(root: site.url)

        XCTAssertTrue(summary.contains("Changed version: 2.2.1 -> \(SumiMetadata.currentVersion)"))
        XCTAssertEqual(try ConfigLoader.load(root: site.url).version, SumiMetadata.currentVersion)
    }

    func testKeepsAnEditedFooterAndPointsAtTheCreditLeftInIt() throws {
        let site = try oldSite()
        let footer = site.url.appendingPathComponent("theme/components/SiteFooter.plume")
        let edited = try String(contentsOf: footer, encoding: .utf8).replacingOccurrences(of: "Top &uarr;", with: "Back to top")
        try edited.write(to: footer, atomically: true, encoding: .utf8)

        let summary = try SumiMigration.run(root: site.url)

        XCTAssertEqual(try String(contentsOf: site.url.appendingPathComponent("theme/components/SiteFooter.sumi"), encoding: .utf8), edited)
        XCTAssertTrue(summary.contains("Check theme/components/SiteFooter.sumi: it reads theme.showPoweredBy, which Sumi no longer has, so remove the footer credit there by hand"))
        XCTAssertFalse(summary.contains { $0.hasPrefix("Updated theme/components/SiteFooter.sumi") })
    }

    func testDoesNothingOnASiteThatAlreadyMoved() throws {
        let site = try oldSite()
        _ = try SumiMigration.run(root: site.url)
        let moved = try snapshot(site.url)

        XCTAssertEqual(try SumiMigration.run(root: site.url), [])
        XCTAssertEqual(try snapshot(site.url), moved)
    }

    func testDoesNothingOnAFreshSumiSite() throws {
        let site = try TemporaryDirectory()
        _ = try SiteInitializer.initSite(at: site.url)
        let fresh = try snapshot(site.url)

        XCTAssertEqual(try SumiMigration.run(root: site.url), [])
        XCTAssertEqual(try snapshot(site.url), fresh)
    }

    func testStopsWithoutChangesWhenTheNewConfigAlreadyExists() throws {
        let site = try oldSite()
        try "{}\n".write(to: site.url.appendingPathComponent("sumi.json"), atomically: true, encoding: .utf8)
        let before = try snapshot(site.url)

        XCTAssertThrowsError(try SumiMigration.run(root: site.url)) { error in
            XCTAssertTrue(String(describing: error).contains("inkstead-writer.json and sumi.json both exist"), String(describing: error))
            XCTAssertTrue(String(describing: error).contains("Nothing was changed."))
        }
        XCTAssertEqual(try snapshot(site.url), before)
    }

    func testStopsWithoutChangesWhenATemplateAlreadyHasItsNewName() throws {
        let site = try oldSite()
        try "<p>Mine</p>\n".write(to: site.url.appendingPathComponent("theme/pages/home.sumi"), atomically: true, encoding: .utf8)
        try "#!/bin/sh\n".write(to: site.url.appendingPathComponent("sumi"), atomically: true, encoding: .utf8)
        let before = try snapshot(site.url)

        XCTAssertThrowsError(try SumiMigration.run(root: site.url)) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("theme/pages/home.plume and theme/pages/home.sumi both exist"), message)
            XCTAssertTrue(message.contains("inkstead-writer and sumi both exist"), message)
        }
        XCTAssertEqual(try snapshot(site.url), before)
    }

    func testRenamesTheAppConnectionToInkstead() throws {
        let site = try TemporaryDirectory()
        try """
        {
          "inkstead": { "version": "2.0.0" },
          "site": { "title": "My Website", "url": "https://example.com", "author": "Your Name" },
          "connection": { "provider": "github", "repository": "me/site", "categories": ["Notes"] }
        }
        """.write(to: site.url.appendingPathComponent("inkstead-writer.json"), atomically: true, encoding: .utf8)

        let summary = try SumiMigration.run(root: site.url)

        XCTAssertTrue(summary.contains("Moved inkstead.version to version"))
        XCTAssertTrue(summary.contains("Renamed connection to inkstead"))
        let config = try ConfigLoader.load(root: site.url)
        XCTAssertEqual(config.connection?.repository, "me/site")
        XCTAssertEqual(config.connection?.categories, ["Notes"])
        let json = try String(contentsOf: site.url.appendingPathComponent("sumi.json"), encoding: .utf8)
        XCTAssertTrue(json.contains(#""inkstead" : {"#), json)
        XCTAssertFalse(json.contains(#""connection""#), json)
    }

    func testLeavesASiteThatNeedsHandConvertedTemplatesUntouched() throws {
        let site = try TemporaryDirectory()
        try FileManager.default.createDirectory(at: site.url.appendingPathComponent("theme"), withIntermediateDirectories: true)
        try """
        { "inkstead": { "version": "1.2.0" }, "site": { "title": "My Website", "url": "https://example.com", "author": "Your Name" } }
        """.write(to: site.url.appendingPathComponent("inkstead.json"), atomically: true, encoding: .utf8)
        try "{% capture title %}Hi{% endcapture %}".write(to: site.url.appendingPathComponent("theme/layout.liquid"), atomically: true, encoding: .utf8)
        try "<p>{title}</p>\n".write(to: site.url.appendingPathComponent("theme/home.plume"), atomically: true, encoding: .utf8)
        let before = try snapshot(site.url)

        XCTAssertThrowsError(try SumiMigration.run(root: site.url)) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("theme/layout.liquid"), message)
            XCTAssertTrue(message.contains("Nothing was changed."), message)
        }
        XCTAssertEqual(try snapshot(site.url), before)
    }

    func testMovesAnInksteadJSONSiteAndItsLegacyVersionRecord() throws {
        let site = try TemporaryDirectory()
        try """
        { "inkstead": { "version": "2.0.0" }, "site": { "title": "My Website", "url": "https://example.com", "author": "Your Name" } }
        """.write(to: site.url.appendingPathComponent("inkstead.json"), atomically: true, encoding: .utf8)
        try "#!/bin/sh\n".write(to: site.url.appendingPathComponent("inkstead"), atomically: true, encoding: .utf8)

        let summary = try SumiMigration.run(root: site.url)

        XCTAssertTrue(summary.contains("Renamed inkstead.json -> sumi.json"))
        XCTAssertTrue(summary.contains("Moved inkstead.version to version"))
        XCTAssertTrue(summary.contains("Removed inkstead"))
        XCTAssertTrue(summary.contains("Changed version: 2.0.0 -> \(SumiMetadata.currentVersion)"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: site.url.appendingPathComponent("inkstead.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: site.url.appendingPathComponent("inkstead").path))
        let config = try String(contentsOf: site.url.appendingPathComponent("sumi.json"), encoding: .utf8)
        XCTAssertFalse(config.contains("\"inkstead\""))
        XCTAssertEqual(config, try ConfigLoader.encode(try ConfigLoader.load(root: site.url)))
    }

    func testRenamesRuntimeNamesWithoutTouchingOrdinaryWords() {
        XCTAssertEqual(
            SumiMigration.renameRuntimeNames(in: #"<a href="/assets/plume/x.js" data-plume-on-click="go">A plume of smoke. Plume.</a>"#),
            #"<a href="/assets/sumi/x.js" data-sumi-on-click="go">A plume of smoke. Plume.</a>"#
        )
        XCTAssertEqual(
            SumiMigration.renameRuntimeNames(in: "window.PlumeFeed.load(); PlumeFeed.load(); --plume-progress-color: red; fetch(u, { headers: { 'X-Plume-Frame': '1' } })"),
            "window.SumiFeed.load(); SumiFeed.load(); --sumi-progress-color: red; fetch(u, { headers: { 'X-Sumi-Frame': '1' } })"
        )
    }

    private func oldSite() throws -> TemporaryDirectory {
        let site = try TemporaryDirectory()
        try FileManager.default.removeItem(at: site.url)
        try FileManager.default.copyItem(at: Self.fixture, to: site.url)
        return site
    }

    /// Every file under `root` with its contents, keyed by site-relative path.
    private func snapshot(_ root: URL) throws -> [String: String] {
        var files: [String: String] = [:]
        let rootPath = root.standardizedFileURL.path + "/"
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])
        while let file = enumerator?.nextObject() as? URL {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let path = String(file.standardizedFileURL.path.dropFirst(rootPath.count))
            files[path] = try String(contentsOf: file, encoding: .utf8)
        }
        return files
    }
}
