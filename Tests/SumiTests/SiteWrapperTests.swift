import Foundation
import XCTest
@testable import Sumi

final class SiteWrapperTests: XCTestCase {
    func testGlobalLauncherFindsSiteRootAndExecsCachedSiteVersion() throws {
        #if os(Windows)
        throw XCTSkip("The generated launcher is a POSIX shell script.")
        #else
        let temp = try TemporaryDirectory()
        let bin = temp.url.appendingPathComponent("bin")
        let site = temp.url.appendingPathComponent("site")
        let nested = site.appendingPathComponent("content/posts")
        let cache = temp.url.appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try """
        {
          "version": "2.0.0",
          "site": { "title": "My Website", "url": "https://example.com", "author": "Your Name" }
        }
        """.write(to: site.appendingPathComponent("sumi.json"), atomically: true, encoding: .utf8)

        let launcher = bin.appendingPathComponent("sumi")
        try SiteWrapper.script.write(to: launcher, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcher.path)

        let platform = try SumiReleaseResolver.currentPlatform()
        let cached = SumiReleaseResolver.cachedBinary(cacheRoot: cache, version: "2.0.0", platform: platform)
        try FileManager.default.createDirectory(at: cached.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        #!/bin/sh
        printf 'cwd=%s\\n' "$PWD"
        printf 'args=%s\\n' "$*"
        """.write(to: cached, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cached.path)

        let output = try runLauncher(launcher, arguments: ["build", "--verbose"], cwd: nested, environment: [
            "SUMI_CACHE_DIR": cache.path
        ])

        XCTAssertEqual(output.status, 0)
        let cwdLine = try XCTUnwrap(output.stdout.components(separatedBy: .newlines).first { $0.hasPrefix("cwd=") })
        let launchedCWD = URL(fileURLWithPath: String(cwdLine.dropFirst(4))).standardizedFileURL.resolvingSymlinksInPath()
        XCTAssertEqual(launchedCWD.path, site.standardizedFileURL.resolvingSymlinksInPath().path)
        XCTAssertTrue(output.stdout.contains("args=build --verbose"))
        XCTAssertEqual(output.stderr, "")
        #endif
    }

    func testGlobalLauncherRunsTheLatestSumiOnAnInksteadWriterSite() throws {
        #if os(Windows)
        throw XCTSkip("The generated launcher is a POSIX shell script.")
        #else
        let temp = try TemporaryDirectory()
        let bin = temp.url.appendingPathComponent("bin")
        let site = temp.url.appendingPathComponent("site")
        let cache = temp.url.appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: site, withIntermediateDirectories: true)
        try """
        { "version": "2.3.1", "site": { "title": "My Website", "url": "https://example.com", "author": "Your Name" } }
        """.write(to: site.appendingPathComponent("inkstead-writer.json"), atomically: true, encoding: .utf8)

        // The latest release, as the GitHub API reports it.
        let curl = bin.appendingPathComponent("curl")
        try "#!/bin/sh\nprintf '{ \"tag_name\": \"v9.0.0\" }\\n'\n".write(to: curl, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: curl.path)

        let launcher = bin.appendingPathComponent("sumi")
        try SiteWrapper.script.write(to: launcher, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcher.path)

        let platform = try SumiReleaseResolver.currentPlatform()
        let cached = SumiReleaseResolver.cachedBinary(cacheRoot: cache, version: "9.0.0", platform: platform)
        try FileManager.default.createDirectory(at: cached.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\nprintf 'latest args=%s\\n' \"$*\"\n".write(to: cached, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cached.path)

        let output = try runLauncher(launcher, arguments: ["build"], cwd: site, environment: [
            "SUMI_CACHE_DIR": cache.path,
            "PATH": "\(bin.path):/usr/bin:/bin"
        ])

        XCTAssertEqual(output.status, 0, output.stderr)
        XCTAssertEqual(output.stdout, "latest args=build\n")
        #endif
    }

    func testGlobalLauncherExplainsNonSiteCommandsOutsideASite() throws {
        #if os(Windows)
        throw XCTSkip("The generated launcher is a POSIX shell script.")
        #else
        let temp = try TemporaryDirectory()
        let launcher = temp.url.appendingPathComponent("sumi")
        let cwd = temp.url.appendingPathComponent("elsewhere")
        try FileManager.default.createDirectory(at: cwd, withIntermediateDirectories: true)
        try SiteWrapper.script.write(to: launcher, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcher.path)

        let output = try runLauncher(launcher, arguments: ["build"], cwd: cwd, environment: [
            "SUMI_CACHE_DIR": temp.url.appendingPathComponent("cache").path
        ])

        XCTAssertNotEqual(output.status, 0)
        XCTAssertTrue(output.stderr.contains("not inside a Sumi site"))
        XCTAssertTrue(output.stderr.contains("sumi init my-site"))
        XCTAssertEqual(output.stdout, "")
        #endif
    }

    private func runLauncher(
        _ launcher: URL,
        arguments: [String],
        cwd: URL,
        environment: [String: String]
    ) throws -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.currentDirectoryURL = cwd
        process.executableURL = launcher
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        return (
            process.terminationStatus,
            String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }
}
