import Foundation

/// Moves an Inkstead Writer site to Sumi.
///
/// Sumi runs this before every site command. It renames what changed when
/// Inkstead Writer and its Plume templates became Sumi, then runs the regular
/// migration so the site ends up as a fresh Sumi site would. A site without an
/// Inkstead Writer config has nothing to move, so running it again does nothing.
public enum SumiMigration {
    static let oldConfigFileNames = ["inkstead-writer.json", "inkstead.json"]
    static let oldLauncher = "inkstead-writer"
    static let olderLauncher = "inkstead"
    static let oldReadme = "# My Inkstead Writer Site\n\nDocumentation: https://inkstead.app/writer\n"
    static let themeTextExtensions: Set<String> = ["sumi", "css", "js", "mjs"]

    /// SHA-256 of the footer and styles each Inkstead Writer 2.x release put
    /// in an ejected theme, with trailing newlines trimmed. A theme that still
    /// has one of these unedited gets Sumi's, which has no footer credit.
    static let stockTemplates: [String: Set<String>] = [
        "components/SiteFooter.sumi": [
            "ac33b6085a54af76042b63dc0f0af071e2201164a0d829dca5f8696e79c98b55",
            "d849623ec06083c9199ca0b4669bf713a4376b77b70cf49c389a3542257a17e8"
        ],
        "components/SiteStyles.sumi": [
            "a011a637456cffd76471673b038bd2e311949404bd99088cf96d13a286c650ae",
            "581c65b0ffdeb650f2521a689796923994ec1300dbc4df4a9422bcef90cbe78c"
        ]
    ]

    /// Names a theme's own templates, styles and scripts can use to reach the
    /// template runtime, with what each is called now.
    static let runtimeRenames: [(pattern: String, replacement: String)] = [
        (#"\.plume\b"#, ".sumi"),
        (#"\bwindow\.Plume"#, "window.Sumi"),
        (#"\bPlume(Feed)?\.(?=[A-Za-z_$])"#, "Sumi$1."),
        (#"\bdata-plume-"#, "data-sumi-"),
        (#"\bdataset\.plume(?=[A-Z])"#, "dataset.sumi"),
        (#"\bplume:navigate"#, "sumi:navigate"),
        (#"--plume-"#, "--sumi-"),
        (#"\bplume-(runtime|frame|stream|progress-bar)"#, "sumi-$1"),
        (#"\bassets/plume/"#, "assets/sumi/"),
        (#"\bX-Plume-"#, "X-Sumi-"),
        (#"__plume"#, "__sumi")
    ]

    /// Moves the site in `root` if it is an Inkstead Writer site. Returns one
    /// line per file renamed or rewritten and per config key or value changed,
    /// or nothing when the site is already on Sumi.
    public static func run(root: URL) throws -> [String] {
        let oldConfigs = oldConfigFileNames.filter { exists($0, in: root) }
        guard let oldConfig = oldConfigs.first else { return [] }

        // Work out every change first, so a name that is already taken stops
        // the move before anything is touched.
        var conflicts: [String] = []
        if oldConfigs.count > 1 {
            conflicts.append("\(oldConfigs.joined(separator: " and ")) both exist")
        }
        if exists(SumiMetadata.configFileName, in: root) {
            conflicts.append("\(oldConfig) and \(SumiMetadata.configFileName) both exist")
        }
        let launcherRename = exists(oldLauncher, in: root)
        if launcherRename, exists(SiteWrapper.path, in: root) {
            conflicts.append("\(oldLauncher) and \(SiteWrapper.path) both exist")
        }

        var config = try readConfig(root.appendingPathComponent(oldConfig))
        let theme = (config["theme"] as? [String: Any])?["path"] as? String ?? "theme"
        var configChanges = ["Renamed \(oldConfig) -> \(SumiMetadata.configFileName)"]
        if config["$schema"] as? String != SumiMetadata.configSchemaURL {
            configChanges.append("Changed $schema: \(config["$schema"] as? String ?? "none") -> \(SumiMetadata.configSchemaURL)")
            config["$schema"] = SumiMetadata.configSchemaURL
        }
        if let legacy = config.removeValue(forKey: "inkstead") as? [String: Any] {
            if config["version"] == nil, let version = legacy["version"] as? String {
                config["version"] = version
                configChanges.append("Moved inkstead.version to version")
            } else {
                configChanges.append("Removed inkstead")
            }
        }
        // The Inkstead app's settings take the app's name, now that the old
        // inkstead version record above is out of the way.
        if let connection = config.removeValue(forKey: "connection") {
            config["inkstead"] = connection
            configChanges.append("Renamed connection to inkstead")
        }
        if var themeConfig = config["theme"] as? [String: Any], themeConfig.removeValue(forKey: "showPoweredBy") != nil {
            config["theme"] = themeConfig.isEmpty ? nil : themeConfig
            configChanges.append("Removed theme.showPoweredBy")
        }

        let templateRenames = try files(in: root.appendingPathComponent(theme), root: root)
            .filter { $0.hasSuffix(".plume") }
            .map { (from: $0, to: String($0.dropLast(".plume".count)) + ".sumi") }
        for rename in templateRenames where exists(rename.to, in: root) {
            conflicts.append("\(rename.from) and \(rename.to) both exist")
        }

        guard conflicts.isEmpty else {
            throw SumiError.config("""
                This Inkstead Writer site can't move to Sumi yet, because some of its new names are already taken:
                \(conflicts.map { "  - \($0)" }.joined(separator: "\n"))
                Nothing was changed. Merge or remove the newer files, then run Sumi again.
                """)
        }

        // A site old enough to need hand-converted templates stays as it is
        // until they are done, so the launcher keeps running the latest Sumi.
        let decoded = try JSONDecoder().decode(SumiConfig.self, from: JSONSerialization.data(withJSONObject: config))
        let manualSteps = try MigrationPlanner.plan(root: root, config: decoded).actions.filter(\.isManual)
        guard manualSteps.isEmpty else {
            throw SumiError.config("""
                This Inkstead Writer site needs these changes by hand before it can move to Sumi:
                \(manualSteps.map { "  - \($0.description)" }.joined(separator: "\n"))
                Nothing was changed. Make the changes, then run Sumi again.
                """)
        }

        // Rename and rewrite the site's files. The config moves last, so a
        // move that stops halfway is picked up again on the next run.
        var summary: [String] = []
        if launcherRename {
            try move(oldLauncher, to: SiteWrapper.path, in: root)
            summary.append("Renamed \(oldLauncher) -> \(SiteWrapper.path)")
        }
        if exists(olderLauncher, in: root) {
            try FileManager.default.removeItem(at: root.appendingPathComponent(olderLauncher))
            summary.append("Removed \(olderLauncher)")
        }
        for rename in templateRenames {
            try move(rename.from, to: rename.to, in: root)
            summary.append("Renamed \(rename.from) -> \(rename.to)")
        }
        for (name, hashes) in stockTemplates.sorted(by: { $0.key < $1.key }) {
            let path = "\(theme)/\(name)"
            guard let source = try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8),
                  hashes.contains(SHA256.hex(Data(trimmingTrailingNewlines(source).utf8))),
                  let current = DefaultTemplates.components["DefaultTemplates/\(name)"] else { continue }
            try current.write(to: root.appendingPathComponent(path), atomically: true, encoding: .utf8)
            summary.append("Updated \(path): Sumi's default, without the footer credit")
        }
        for path in try themeTextFiles(theme: theme, config: config, root: root) {
            let url = root.appendingPathComponent(path)
            let source = try String(contentsOf: url, encoding: .utf8)
            let renamed = renameRuntimeNames(in: source)
            if renamed != source {
                try renamed.write(to: url, atomically: true, encoding: .utf8)
                summary.append("Updated \(path): Sumi runtime names")
            }
            if renamed.contains("showPoweredBy") {
                summary.append("Check \(path): it reads theme.showPoweredBy, which Sumi no longer has, so remove the footer credit there by hand")
            }
        }
        let readme = root.appendingPathComponent("README.md")
        if (try? String(contentsOf: readme, encoding: .utf8)) == oldReadme {
            try SiteInitializer.readme.write(to: readme, atomically: true, encoding: .utf8)
            summary.append("Updated README.md")
        }

        summary.append(contentsOf: configChanges)
        let previousVersion = config["version"] as? String
        try writeConfig(config, to: root.appendingPathComponent(SumiMetadata.configFileName))
        try FileManager.default.removeItem(at: root.appendingPathComponent(oldConfig))

        // Bring the site up to date the regular way: record this version and
        // refresh the launcher and generated workflow.
        let migration = try MigrationRunner.run(root: root)
        summary.append(contentsOf: migration.changedFiles.map { "Updated \($0)" })
        let version = try ConfigLoader.load(root: root).version
        if version != previousVersion {
            summary.append("Changed version: \(previousVersion ?? "none") -> \(version)")
        }
        return summary
    }

    private static func trimmingTrailingNewlines(_ source: String) -> String {
        var trimmed = Substring(source)
        while trimmed.last == "\n" {
            trimmed = trimmed.dropLast()
        }
        return String(trimmed)
    }

    static func renameRuntimeNames(in source: String) -> String {
        var result = source
        for rename in runtimeRenames {
            let regex = try! NSRegularExpression(pattern: rename.pattern)
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: rename.replacement
            )
        }
        return result
    }

    /// The theme's templates, styles and scripts, plus any passthrough assets,
    /// which is where a site's own code can name the template runtime.
    private static func themeTextFiles(theme: String, config: [String: Any], root: URL) throws -> [String] {
        var directories = [theme]
        let passthrough = (config["assets"] as? [String: Any])?["passthrough"] as? [[String: Any]] ?? []
        directories.append(contentsOf: passthrough.compactMap { $0["from"] as? String })
        var paths: [String] = []
        for directory in directories {
            paths.append(contentsOf: try files(in: root.appendingPathComponent(directory), root: root))
        }
        return Array(Set(paths)).sorted().filter { themeTextExtensions.contains(($0 as NSString).pathExtension) }
    }

    /// Site-relative paths of the regular files at or under `url`, sorted.
    private static func files(in url: URL, root: URL) throws -> [String] {
        let rootPath = root.standardizedFileURL.path + "/"
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }
        guard isDirectory.boolValue else {
            return [String(url.standardizedFileURL.path.dropFirst(rootPath.count))]
        }
        var paths: [String] = []
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey])
        while let file = enumerator?.nextObject() as? URL {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            paths.append(String(file.standardizedFileURL.path.dropFirst(rootPath.count)))
        }
        return paths.sorted()
    }

    private static func exists(_ path: String, in root: URL) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path)
    }

    private static func move(_ path: String, to destination: String, in root: URL) throws {
        try FileManager.default.moveItem(at: root.appendingPathComponent(path), to: root.appendingPathComponent(destination))
    }

    private static func readConfig(_ url: URL) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw SumiError.config("\(url.lastPathComponent) must contain a JSON object.")
        }
        return object
    }

    private static func writeConfig(_ config: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try (String(decoding: data, as: UTF8.self) + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
