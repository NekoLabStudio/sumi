import Foundation
import XCTest
@testable import Sumi

final class UpdateTests: XCTestCase {
    func testLatestReleaseVersionParsesGitHubTag() async throws {
        let version = try await SiteUpdater.latestReleaseVersion { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.github.com/repos/NekoLabStudio/sumi/releases/latest")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "sumi/\(SumiMetadata.currentVersion)")
            return HTTPResponse(statusCode: 200, body: Data(#"{ "tag_name": "v2.3.4" }"#.utf8))
        }

        XCTAssertEqual(version, "2.3.4")
    }

    func testUpdateAppliesKnownMigrationAndInstallsWrapper() async throws {
        let root = try TemporaryDirectory()
        try """
        {
          "version": "1.2.0",
          "site": { "title": "My Website", "url": "https://example.com", "author": "Your Name" }
        }
        """.write(to: root.url.appendingPathComponent("sumi.json"), atomically: true, encoding: .utf8)

        let result = try await SiteUpdater.update(root: root.url, http: { _ in
            HTTPResponse(statusCode: 200, body: Data(#"{ "tag_name": "v2.0.0" }"#.utf8))
        })

        XCTAssertEqual(result.previousVersion, "1.2.0")
        XCTAssertEqual(result.targetVersion, "2.0.0")
        XCTAssertFalse(result.delegatedToDownloadedBinary)
        XCTAssertTrue(result.changedFiles.contains("sumi.json"))
        XCTAssertTrue(result.changedFiles.contains("sumi"))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: root.url.appendingPathComponent("sumi").path))
        let config = try ConfigLoader.load(root: root.url)
        XCTAssertEqual(config.version, "2.0.0")
    }

    func testUpdateDryRunPlansKnownMigrationWithoutChangingFiles() async throws {
        let root = try TemporaryDirectory()
        try """
        {
          "version": "1.2.0",
          "site": { "title": "My Website", "url": "https://example.com", "author": "Your Name" }
        }
        """.write(to: root.url.appendingPathComponent("sumi.json"), atomically: true, encoding: .utf8)

        let result = try await SiteUpdater.update(root: root.url, dryRun: true, http: { _ in
            HTTPResponse(statusCode: 200, body: Data(#"{ "tag_name": "v2.0.0" }"#.utf8))
        })

        XCTAssertTrue(result.dryRun)
        XCTAssertEqual(result.previousVersion, "1.2.0")
        XCTAssertEqual(result.targetVersion, "2.0.0")
        XCTAssertTrue(result.changedFiles.contains("sumi.json"))
        XCTAssertTrue(result.changedFiles.contains("sumi"))
        XCTAssertEqual(try ConfigLoader.load(root: root.url).recordedVersion, "1.2.0")
    }

    func testUpdateDelegatesFutureMigrationsToDownloadedBinary() async throws {
        let root = try TemporaryDirectory()
        try """
        {
          "version": "2.0.0",
          "site": { "title": "My Website", "url": "https://example.com", "author": "Your Name" }
        }
        """.write(to: root.url.appendingPathComponent("sumi.json"), atomically: true, encoding: .utf8)
        let binary = root.url.appendingPathComponent("cache/v9.0.0/macos-arm64/sumi")
        var resolvedVersion: String?
        var ranBinary: URL?

        let result = try await SiteUpdater.update(
            root: root.url,
            requestedVersion: "9.0.0",
            resolveBinary: { version, root in
                resolvedVersion = version
                try FileManager.default.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
                try "".write(to: binary, atomically: true, encoding: .utf8)
                return binary
            },
            runMigrationBinary: { binary, root in
                ranBinary = binary
            }
        )

        XCTAssertEqual(resolvedVersion, "9.0.0")
        XCTAssertEqual(ranBinary, binary)
        XCTAssertTrue(result.delegatedToDownloadedBinary)
    }

    func testUpdateFutureDryRunDoesNotDownloadBinary() async throws {
        let root = try TemporaryDirectory()
        try """
        {
          "version": "2.0.0",
          "site": { "title": "My Website", "url": "https://example.com", "author": "Your Name" }
        }
        """.write(to: root.url.appendingPathComponent("sumi.json"), atomically: true, encoding: .utf8)
        var resolved = false
        var ran = false

        let result = try await SiteUpdater.update(
            root: root.url,
            requestedVersion: "9.0.0",
            dryRun: true,
            resolveBinary: { _, _ in
                resolved = true
                return root.url.appendingPathComponent("sumi")
            },
            runMigrationBinary: { _, _ in
                ran = true
            }
        )

        XCTAssertTrue(result.dryRun)
        XCTAssertTrue(result.delegatedToDownloadedBinary)
        XCTAssertFalse(resolved)
        XCTAssertFalse(ran)
    }

    func testReleaseResolverNamesAssetsForSupportedPlatforms() throws {
        XCTAssertEqual(
            SumiReleaseResolver.assetName(for: SumiReleasePlatform(os: "macos", arch: "arm64"), version: "9.0.0"),
            "sumi-v9.0.0-macos-arm64.tar.gz"
        )
        XCTAssertEqual(
            SumiReleaseResolver.assetName(for: SumiReleasePlatform(os: "linux", arch: "aarch64"), version: "9.0.0"),
            "sumi-v9.0.0-linux-aarch64.tar.gz"
        )
    }

    func testSeedsCurrentBinaryIntoCache() throws {
        let root = try TemporaryDirectory()
        let cacheRoot = root.url.appendingPathComponent("cache")
        let fakeBinary = root.url.appendingPathComponent("source-sumi")
        try "binary".write(to: fakeBinary, atomically: true, encoding: .utf8)

        try SumiReleaseResolver.seedCurrentBinary(root: root.url, executablePath: fakeBinary.path, cacheRoot: cacheRoot)

        let cached = try SumiReleaseResolver.cachedBinary(cacheRoot: cacheRoot, version: SumiMetadata.currentVersion, platform: SumiReleaseResolver.currentPlatform())
        XCTAssertEqual(try String(contentsOf: cached, encoding: .utf8), "binary")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: cached.path))
    }

    func testReleaseResolverUsesExecutableCachedBinaryWithoutDownloading() throws {
        let root = try TemporaryDirectory()
        let platform = SumiReleasePlatform(os: "linux", arch: "x86_64")
        let cacheRoot = root.url.appendingPathComponent("cache")
        let cached = SumiReleaseResolver.cachedBinary(cacheRoot: cacheRoot, version: "2.0.0", platform: platform)
        try FileManager.default.createDirectory(at: cached.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cached".write(to: cached, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cached.path)
        var attemptedDownload = false

        let resolved = try SumiReleaseResolver.resolve(version: "2.0.0", root: root.url, platform: platform, cacheRoot: cacheRoot) { _, _ in
            attemptedDownload = true
        }

        XCTAssertEqual(resolved, cached)
        XCTAssertFalse(attemptedDownload)
    }

    func testReleaseResolverVerifiesChecksumBeforeExtractingArchive() throws {
        let root = try TemporaryDirectory()
        let platform = SumiReleasePlatform(os: "macos", arch: "arm64")
        let asset = SumiReleaseResolver.assetName(for: platform, version: "9.0.0")
        let archiveBytes = Data("archive bytes".utf8)
        let checksum = SHA256.hex(archiveBytes)
        let cacheRoot = root.url.appendingPathComponent("cache")
        var extracted = false

        let binary = try SumiReleaseResolver.resolve(version: "9.0.0", root: root.url, platform: platform, cacheRoot: cacheRoot) { command, _ in
            if command.executable == "curl" {
                let output = URL(fileURLWithPath: try XCTUnwrap(command.arguments.last))
                if command.arguments.contains(where: { $0.hasSuffix("/sumi-v9.0.0-SHA256SUMS") }) {
                    try "\(checksum)  \(asset)\n".write(to: output, atomically: true, encoding: .utf8)
                } else {
                    try archiveBytes.write(to: output)
                }
            } else if command.executable == "tar" {
                extracted = true
                let cache = SumiReleaseResolver.cachedBinary(cacheRoot: cacheRoot, version: "9.0.0", platform: platform).deletingLastPathComponent()
                try "binary".write(to: cache.appendingPathComponent("sumi"), atomically: true, encoding: .utf8)
            } else {
                XCTFail("Unexpected command \(command.executable)")
            }
        }

        XCTAssertTrue(extracted)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binary.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: binary.deletingLastPathComponent().appendingPathExtension("lock").path))
    }

    func testReleaseResolverReclaimsStaleDownloadLock() throws {
        let root = try TemporaryDirectory()
        let platform = SumiReleasePlatform(os: "macos", arch: "arm64")
        let asset = SumiReleaseResolver.assetName(for: platform, version: "9.0.0")
        let archiveBytes = Data("archive bytes".utf8)
        let checksum = SHA256.hex(archiveBytes)
        let cacheRoot = root.url.appendingPathComponent("cache")
        let cache = SumiReleaseResolver.cachedBinary(cacheRoot: cacheRoot, version: "9.0.0", platform: platform).deletingLastPathComponent()
        let lock = cache.appendingPathExtension("lock")
        try FileManager.default.createDirectory(at: lock, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -3600)], ofItemAtPath: lock.path)

        let binary = try SumiReleaseResolver.resolve(version: "9.0.0", root: root.url, platform: platform, cacheRoot: cacheRoot) { command, _ in
            if command.executable == "curl" {
                let output = URL(fileURLWithPath: try XCTUnwrap(command.arguments.last))
                if command.arguments.contains(where: { $0.hasSuffix("/sumi-v9.0.0-SHA256SUMS") }) {
                    try "\(checksum)  \(asset)\n".write(to: output, atomically: true, encoding: .utf8)
                } else {
                    try archiveBytes.write(to: output)
                }
            } else if command.executable == "tar" {
                try "binary".write(to: cache.appendingPathComponent("sumi"), atomically: true, encoding: .utf8)
            } else {
                XCTFail("Unexpected command \(command.executable)")
            }
        }

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binary.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: lock.path))
    }

    func testReleaseResolverRejectsChecksumMismatch() throws {
        let root = try TemporaryDirectory()
        let platform = SumiReleasePlatform(os: "macos", arch: "arm64")
        let asset = SumiReleaseResolver.assetName(for: platform, version: "9.0.0")
        let cacheRoot = root.url.appendingPathComponent("cache")
        var extracted = false

        XCTAssertThrowsError(try SumiReleaseResolver.resolve(version: "9.0.0", root: root.url, platform: platform, cacheRoot: cacheRoot) { command, _ in
            if command.executable == "curl" {
                let output = URL(fileURLWithPath: try XCTUnwrap(command.arguments.last))
                if command.arguments.contains(where: { $0.hasSuffix("/sumi-v9.0.0-SHA256SUMS") }) {
                    try "\(String(repeating: "0", count: 64))  \(asset)\n".write(to: output, atomically: true, encoding: .utf8)
                } else {
                    try Data("archive bytes".utf8).write(to: output)
                }
            } else if command.executable == "tar" {
                extracted = true
            }
        }) { error in
            XCTAssertTrue(String(describing: error).contains("Checksum verification failed"))
        }
        XCTAssertFalse(extracted)
    }
}
