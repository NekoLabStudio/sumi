import Foundation
import SumiLanguage

public enum ThemeCheckSeverity: String, Equatable {
    case error
    case warning
}

public struct ThemeCheckIssue: Equatable {
    public var severity: ThemeCheckSeverity
    public var path: String
    public var message: String

    public init(path: String, message: String, severity: ThemeCheckSeverity = .error) {
        self.severity = severity
        self.path = path
        self.message = message
    }
}

public struct ThemeCheckResult: Equatable {
    public var checkedFiles: [String]
    public var issues: [ThemeCheckIssue]

    public init(checkedFiles: [String], issues: [ThemeCheckIssue]) {
        self.checkedFiles = checkedFiles
        self.issues = issues
    }

    public var passed: Bool {
        issues.allSatisfy { $0.severity == .warning }
    }

    public var errors: [ThemeCheckIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [ThemeCheckIssue] {
        issues.filter { $0.severity == .warning }
    }
}

public enum ThemeChecker {
    public static func check(root: URL, config: SumiConfig) throws -> ThemeCheckResult {
        let themePath = config.theme?.path ?? "theme"
        let themeRoot = root.appendingPathComponent(themePath)
        let files = sumiFiles(in: themeRoot)
        let components = try componentSources(in: themeRoot.appendingPathComponent("components"))
        let environment = try SumiTemplateEnvironment(componentSources: components)
        var issues: [ThemeCheckIssue] = []
        var seenStyles = Set<String>()
        var seenScripts = Set<String>()
        var seenSumiScripts = Set<String>()
        var seenIssues = Set<String>()
        var seenImages = Set<String>()

        func addIssue(_ issue: ThemeCheckIssue) {
            let key = "\(issue.severity.rawValue)|\(issue.path)|\(issue.message)"
            guard seenIssues.insert(key).inserted else { return }
            issues.append(issue)
        }

        for file in files {
            let relative = relativePath(file, root: root)
            do {
                let source = try String(contentsOf: file, encoding: .utf8)
                let template = try SumiTemplate(source, sourceName: file.path, environment: environment)
                let result = try template.check()
                for style in result.styles where style.file != nil {
                    let key = "\(style.sourceName ?? "")|\(style.file ?? "")"
                    guard seenStyles.insert(key).inserted else { continue }
                    do {
                        _ = try resolveStyleFile(style.file ?? "", sourceName: style.sourceName, root: root, themeRoot: themeRoot)
                    } catch {
                        addIssue(ThemeCheckIssue(path: relativePathForIssue(style.sourceName, fallback: relative, root: root), message: String(describing: error)))
                    }
                }
                for script in result.scripts where script.file != nil {
                    let key = "\(script.sourceName ?? "")|\(script.file ?? "")"
                    guard seenScripts.insert(key).inserted else { continue }
                    do {
                        _ = try resolveScriptFile(script.file ?? "", sourceName: script.sourceName, root: root, themeRoot: themeRoot)
                    } catch {
                        addIssue(ThemeCheckIssue(path: relativePathForIssue(script.sourceName, fallback: relative, root: root), message: String(describing: error)))
                    }
                }
                for script in result.scripts where script.language == .sumi {
                    let key = "\(script.sourceName ?? "")|\(script.file ?? "")|\(script.js ?? "")|\(script.scope ?? "")"
                    guard seenSumiScripts.insert(key).inserted else { continue }
                    do {
                        let source = try scriptSource(script, root: root, themeRoot: themeRoot)
                        _ = try SumiClientScriptCompiler.compile(source, sourceName: script.sourceName)
                    } catch {
                        addIssue(ThemeCheckIssue(path: relativePathForIssue(script.sourceName, fallback: relative, root: root), message: String(describing: error)))
                    }
                }
                for asset in result.assets {
                    guard let path = asset.path else { continue }
                    do {
                        _ = try resolveAssetReference(path, sourceName: asset.sourceName, root: root, themeRoot: themeRoot, config: config)
                    } catch {
                        addIssue(ThemeCheckIssue(path: relativePathForIssue(asset.context, fallback: relative, root: root), message: String(describing: error)))
                    }
                }
                for image in result.images {
                    let issuePath = relativePathForIssue(image.context, fallback: relative, root: root)
                    if image.altExpression == nil || literalString(image.altExpression ?? "") == "" {
                        addIssue(ThemeCheckIssue(path: issuePath, message: "@image should include meaningful alt text.", severity: .warning))
                    }
                    guard let src = image.src else { continue }
                    do {
                        let resolved = try resolveAssetReference(src, sourceName: image.sourceName, root: root, themeRoot: themeRoot, config: config)
                        if case .file(let url) = resolved.kind, ImageEncoder.isSupportedImage(url), (try? ImageOptimizer.dimensions(of: url)) == nil {
                            addIssue(ThemeCheckIssue(path: issuePath, message: "Could not read image dimensions for \(src).", severity: .warning))
                        }
                    } catch {
                        let key = "\(image.sourceName ?? "")|\(src)"
                        guard seenImages.insert(key).inserted else { continue }
                        addIssue(ThemeCheckIssue(path: issuePath, message: String(describing: error)))
                    }
                }
                let smokeContext = sampleContext(root: root, themeRoot: themeRoot, config: config, issuePath: relative) { addIssue($0) }
                do {
                    _ = try template.renderResult(smokeContext)
                } catch {
                    addIssue(ThemeCheckIssue(path: relativePathForIssue(error, fallback: relative, root: root), message: String(describing: error)))
                }
            } catch {
                addIssue(ThemeCheckIssue(path: relativePathForIssue(error, fallback: relative, root: root), message: String(describing: error)))
            }
        }

        return ThemeCheckResult(checkedFiles: files.map { relativePath($0, root: root) }, issues: issues)
    }

    private static func componentSources(in componentsRoot: URL) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: componentsRoot.path) else {
            return [:]
        }
        var sources: [String: String] = [:]
        for file in sumiFiles(in: componentsRoot) {
            sources[file.path] = try String(contentsOf: file, encoding: .utf8)
        }
        return sources
    }

    private static func sumiFiles(in root: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path),
              let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }
        var files: [URL] = []
        for case let file as URL in enumerator where file.pathExtension == "sumi" {
            files.append(file.standardizedFileURL)
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func resolveStyleFile(_ file: String, sourceName: String?, root: URL, themeRoot: URL) throws -> URL {
        let trimmed = file.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SumiError.template("@style file path cannot be empty.")
        }
        let sourceURL = sourceName.flatMap { URL(fileURLWithPath: $0).standardizedFileURL }
        var candidates: [URL] = []
        if let sourceURL, sourceURL.path.hasPrefix(root.standardizedFileURL.path), FileManager.default.fileExists(atPath: sourceURL.path) {
            candidates.append(sourceURL.deletingLastPathComponent().appendingPathComponent(trimmed))
        }
        candidates.append(themeRoot.appendingPathComponent(trimmed))
        candidates.append(root.appendingPathComponent(trimmed))
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        throw SumiError.template("Sumi style file \(file) was not found.")
    }

    private static func resolveScriptFile(_ file: String, sourceName: String?, root: URL, themeRoot: URL) throws -> URL {
        let trimmed = file.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SumiError.template("@script file path cannot be empty.")
        }
        let sourceURL = sourceName.flatMap { URL(fileURLWithPath: $0).standardizedFileURL }
        var candidates: [URL] = []
        if let sourceURL, sourceURL.path.hasPrefix(root.standardizedFileURL.path), FileManager.default.fileExists(atPath: sourceURL.path) {
            candidates.append(sourceURL.deletingLastPathComponent().appendingPathComponent(trimmed))
        }
        candidates.append(themeRoot.appendingPathComponent(trimmed))
        candidates.append(root.appendingPathComponent(trimmed))
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        throw SumiError.template("Sumi script file \(file) was not found.")
    }

    private static func scriptSource(_ script: SumiScriptResource, root: URL, themeRoot: URL) throws -> String {
        if let js = script.js { return js }
        guard let file = script.file else {
            throw SumiError.template("@script must include a JavaScript block or file path.")
        }
        let url = try resolveScriptFile(file, sourceName: script.sourceName, root: root, themeRoot: themeRoot)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func sampleContext(
        root: URL,
        themeRoot: URL,
        config: SumiConfig,
        issuePath: String,
        addIssue: @escaping (ThemeCheckIssue) -> Void
    ) -> [String: Any] {
        let samplePost: [String: Any] = [
            "slug": "sample-post",
            "kind": "article",
            "title": "Sample post",
            "displayTitle": "Sample post",
            "html": SumiSafeHTML("<p>Sample post</p>"),
            "excerpt": SumiSafeHTML("<p>Sample excerpt</p>"),
            "hasMore": false,
            "dateIso": "2026-05-25T00:00:00Z",
            "dateDisplay": "May 25, 2026",
            "dateLongDisplay": "May 25, 2026",
            "date_long_display": "May 25, 2026",
            "lastmodIso": "",
            "urlPath": "/sample-post/",
            "canonicalUrl": "\(config.site.url)/sample-post/",
            "photos": ["https://example.com/photo.jpg"],
            "firstImage": "https://example.com/photo.jpg",
            "alt": "Sample image",
            "categories": ["Sample"],
            "categoryLinks": [["name": "Sample", "slug": "sample", "url": "/categories/sample/"]],
            "syndicationUrls": []
        ]
        let samplePage: [String: Any] = [
            "slug": "sample-page",
            "title": "Sample page",
            "html": SumiSafeHTML("<p>Sample page</p>"),
            "excerpt": SumiSafeHTML("<p>Sample excerpt</p>"),
            "urlPath": "/sample-page/",
            "canonicalUrl": "\(config.site.url)/sample-page/"
        ]
        let sampleCategory: [String: Any] = [
            "name": "Sample",
            "slug": "sample",
            "urlPath": "/categories/sample/",
            "feedPath": "/categories/sample/feed.xml",
            "jsonFeedPath": "/categories/sample/feed.json",
            "posts": [samplePost]
        ]
        let sampleFeedItem: [String: Any] = [
            "comma": "",
            "id": "\(config.site.url)/sample-post/",
            "url": "\(config.site.url)/sample-post/",
            "guid": "\(config.site.url)/sample-post/",
            "title": "Sample post",
            "pubDate": "Mon, 25 May 2026 00:00:00 +0000",
            "html": SumiSafeHTML("<p>Sample post</p>"),
            "contentHTML": SumiSafeHTML("<p>Sample post</p>"),
            "contentText": "Sample post",
            "datePublished": "2026-05-25T00:00:00Z",
            "dateModified": "2026-05-25T00:00:00Z"
        ]
        let sampleFeed: [String: Any] = [
            "format": "xml",
            "version": "https://jsonfeed.org/version/1.1",
            "title": config.site.title,
            "url": "\(config.site.url)/feed.xml",
            "path": "/feed.xml",
            "siteUrl": config.site.url,
            "homePageUrl": "\(config.site.url)/",
            "description": config.site.description ?? "",
            "presentationScriptSrc": "/assets/sumi/feed-sample.js",
            "presentationStyleHrefs": ["/assets/sumi/feed-sample.css"],
            "category": sampleCategory,
            "items": [sampleFeedItem]
        ]
        let pagination: [String: Any] = [
            "current": 1,
            "total": 1,
            "previousUrl": "",
            "nextUrl": ""
        ]
        let meta: [String: Any] = [
            "title": config.site.title,
            "canonicalUrl": config.site.url,
            "description": config.site.description ?? "",
            "feedAlternates": [
                ["type": "application/rss+xml", "title": "\(config.site.title) RSS", "href": "/feed.xml"],
                ["type": "application/feed+json", "title": "\(config.site.title) JSON Feed", "href": "/feed.json"]
            ]
        ]
        let notFound: [String: Any] = [
            "title": "Page not found",
            "description": "The page you requested could not be found.",
            "message": "The page you requested could not be found."
        ]

        return [
            "title": config.site.title,
            "site": [
                "title": config.site.title,
                "url": config.site.url,
                "author": config.site.author,
                "description": config.site.description ?? "",
                "lang": config.site.lang ?? "",
                "avatar": config.site.avatar ?? "",
                "navigation": config.site.navigation?.map { ["name": $0.name, "url": $0.url] } ?? [],
                "social": config.site.social?.map { ["name": $0.name, "url": $0.url, "relMe": $0.relMe ?? false] } ?? []
            ],
            "collections": [
                "posts": [samplePost],
                "pages": [samplePage],
                "categories": [sampleCategory],
                "photoPosts": [samplePost]
            ],
            "data": [:],
            "posts": [samplePost],
            "pages": [samplePage],
            "categories": [sampleCategory],
            "photoPosts": [samplePost],
            "post": samplePost,
            "page": samplePage,
            "category": sampleCategory,
            "pagination": pagination,
            "notFound": notFound,
            "feed": sampleFeed,
            "meta": meta,
            "content": SumiSafeHTML("<main>Sample content</main>"),
            "now": ["year": 2026],
            "asset": SumiFunction { call in
                guard let raw = sumiArgument(named: "path", in: call) ?? firstSumiArgument(call) else {
                    throw SumiError.template("asset() requires a path.")
                }
                let path = stringifySumiValue(raw)
                let resolved = try resolveAssetReference(path, sourceName: call.context?.sourceName, root: root, themeRoot: themeRoot, config: config)
                return resolved.publicPath
            },
            "image": SumiFunction { call in
                let src = stringifySumiValue(sumiArgument(named: "src", in: call) ?? firstSumiArgument(call))
                guard !src.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw SumiError.template("@image requires a source path.")
                }
                if sumiArgument(named: "alt", in: call).map(stringifySumiValue)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    addIssue(ThemeCheckIssue(
                        path: relativePathForIssue(call.context, fallback: issuePath, root: root),
                        message: "@image should include meaningful alt text.",
                        severity: .warning
                    ))
                }
                let resolved = try resolveAssetReference(src, sourceName: call.context?.sourceName, root: root, themeRoot: themeRoot, config: config)
                if case .file(let url) = resolved.kind, ImageEncoder.isSupportedImage(url), (try? ImageOptimizer.dimensions(of: url)) == nil {
                    addIssue(ThemeCheckIssue(
                        path: relativePathForIssue(call.context, fallback: issuePath, root: root),
                        message: "Could not read image dimensions for \(src).",
                        severity: .warning
                    ))
                }
                return SumiSafeHTML(#"<img src="\#(resolved.publicPath)" alt="">"#)
            }
        ]
    }

    private static func resolveAssetReference(_ path: String, sourceName: String?, root: URL, themeRoot: URL, config: SumiConfig) throws -> ThemeResolvedAsset {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SumiError.template("Sumi asset path cannot be empty.")
        }
        if trimmed.range(of: #"^(https?:)?//|^(mailto|tel|data):|^#"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return ThemeResolvedAsset(publicPath: trimmed, kind: .external)
        }
        if trimmed.hasPrefix("/media/") {
            let relative = String(trimmed.dropFirst("/media/".count))
            let source = root.appendingPathComponent(config.content.media).appendingPathComponent(relative)
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw SumiError.template("Sumi asset \(path) was not found.")
            }
            return ThemeResolvedAsset(publicPath: trimmed, kind: .file(source))
        }
        if trimmed.hasPrefix("/") {
            return ThemeResolvedAsset(publicPath: trimmed, kind: .publicPath)
        }
        let sourceURL = sourceName.flatMap { URL(fileURLWithPath: $0).standardizedFileURL }
        var candidates: [URL] = []
        if let sourceURL, sourceURL.path.hasPrefix(root.standardizedFileURL.path), FileManager.default.fileExists(atPath: sourceURL.path) {
            candidates.append(sourceURL.deletingLastPathComponent().appendingPathComponent(trimmed))
        }
        candidates.append(themeRoot.appendingPathComponent(trimmed))
        candidates.append(root.appendingPathComponent(trimmed))
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return ThemeResolvedAsset(publicPath: "/assets/sumi/\(candidate.lastPathComponent)", kind: .file(candidate))
        }
        if trimmed.hasPrefix("\(config.content.media)/") {
            let source = root.appendingPathComponent(trimmed)
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw SumiError.template("Sumi asset \(path) was not found.")
            }
            let relative = String(trimmed.dropFirst(config.content.media.count + 1))
            return ThemeResolvedAsset(publicPath: "/media/\(relative)", kind: .file(source))
        }
        let media = root.appendingPathComponent(config.content.media).appendingPathComponent(trimmed)
        if FileManager.default.fileExists(atPath: media.path) {
            return ThemeResolvedAsset(publicPath: "/media/\(trimmed)", kind: .file(media))
        }
        throw SumiError.template("Sumi asset \(path) was not found.")
    }

    private static func firstSumiArgument(_ call: SumiFunctionCall) -> Any? {
        guard !call.arguments.isEmpty else { return nil }
        return call.arguments[0]
    }

    private static func sumiArgument(named name: String, in call: SumiFunctionCall) -> Any? {
        guard let value = call.namedArguments[name] else { return nil }
        return value
    }

    private static func stringifySumiValue(_ value: Any?) -> String {
        guard let value else { return "" }
        if value is NSNull { return "" }
        if let safe = value as? SumiSafeHTML { return safe.html }
        if let string = value as? String { return string }
        if let bool = value as? Bool { return bool ? "true" : "false" }
        if let int = value as? Int { return String(int) }
        if let double = value as? Double { return String(double) }
        if let array = value as? [Any] { return array.map(stringifySumiValue).filter { !$0.isEmpty }.joined(separator: " ") }
        return String(describing: value)
    }

    private static func literalString(_ expression: String) -> String? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2,
              let first = trimmed.first,
              let last = trimmed.last,
              (first == "\"" || first == "'"),
              first == last else {
            return nil
        }
        return String(trimmed.dropFirst().dropLast())
    }

    private struct ThemeResolvedAsset {
        var publicPath: String
        var kind: ThemeResolvedAssetKind
    }

    private enum ThemeResolvedAssetKind {
        case external
        case publicPath
        case file(URL)
    }

    private static func relativePathForIssue(_ sourceName: String?, fallback: String, root: URL) -> String {
        guard let sourceName else { return fallback }
        return relativePath(URL(fileURLWithPath: sourceName), root: root)
    }

    private static func relativePathForIssue(_ context: SumiSourceContext?, fallback: String, root: URL) -> String {
        guard let context else { return fallback }
        let path = relativePathForIssue(context.sourceName, fallback: fallback, root: root)
        return "\(path):\(context.line):\(context.column)"
    }

    private static func relativePathForIssue(_ error: Error, fallback: String, root: URL) -> String {
        guard let sumiError = error as? SumiTemplateError,
              let sourceName = sumiError.context?.sourceName else {
            return fallback
        }
        return relativePath(URL(fileURLWithPath: sourceName), root: root)
    }

    private static func relativePath(_ url: URL, root: URL) -> String {
        FileTreeSupport.relativePath(of: url, under: root) ?? url.standardizedFileURL.path
    }
}
