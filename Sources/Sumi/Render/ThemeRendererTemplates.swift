import Foundation
import SumiLanguage

extension ThemeRenderer {
    func loadTemplate(_ name: String) throws -> String {
        for sumi in templateCandidates(for: name) {
            if let template = themeTemplates[templateKey(sumi)] {
                return template
            }
        }
        for liquid in legacyTemplateCandidates(for: name) where legacyTemplatePaths.contains(templateKey(liquid)) {
            throw SumiError.template("Legacy Liquid template \(liquid.lastPathComponent) is no longer loaded. Run ./sumi migrate to convert templates to Sumi.")
        }
        guard let template = DefaultTemplates.templates[name] else {
            throw SumiError.template("Template \(name) was not found.")
        }
        return template
    }

    func templatePath(_ name: String) -> String {
        for sumi in templateCandidates(for: name) where themeTemplates[templateKey(sumi)] != nil {
            return sumi.path
        }
        return "DefaultTemplates/\(name).sumi"
    }

    static func loadComponents(root: URL, config: SumiConfig) throws -> [String: String] {
        var components = DefaultTemplates.components
        let componentsDir = themeRoot(root: root, config: config).appendingPathComponent("components")
        guard FileManager.default.fileExists(atPath: componentsDir.path),
              let enumerator = FileManager.default.enumerator(at: componentsDir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return components
        }
        for case let file as URL in enumerator where file.pathExtension == "sumi" {
            components[file.path] = try String(contentsOf: file, encoding: .utf8)
        }
        return components
    }

    func customTemplateExists(_ name: String) throws -> Bool {
        if templateCandidates(for: name).contains(where: { themeTemplates[templateKey($0)] != nil }) {
            return true
        }
        for liquid in legacyTemplateCandidates(for: name) where legacyTemplatePaths.contains(templateKey(liquid)) {
            throw SumiError.template("Legacy Liquid template \(liquid.lastPathComponent) is no longer loaded. Run ./sumi migrate to convert templates to Sumi.")
        }
        return false
    }

    func templateCandidates(for name: String) -> [URL] {
        let themeDir = ThemeRenderer.themeRoot(root: root, config: config)
        if name == "layout" {
            return [
                themeDir.appendingPathComponent("layouts/default.sumi"),
                themeDir.appendingPathComponent("layouts/layout.sumi"),
                themeDir.appendingPathComponent("layout.sumi")
            ]
        }
        return [
            themeDir.appendingPathComponent("pages/\(name).sumi"),
            themeDir.appendingPathComponent("\(name).sumi")
        ]
    }

    func legacyTemplateCandidates(for name: String) -> [URL] {
        templateCandidates(for: name).map { $0.deletingPathExtension().appendingPathExtension("liquid") }
    }

    static func loadThemeTemplates(root: URL, config: SumiConfig) throws -> [String: String] {
        let themeDir = themeRoot(root: root, config: config)
        guard FileManager.default.fileExists(atPath: themeDir.path),
              let enumerator = FileManager.default.enumerator(at: themeDir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return [:]
        }
        var templates: [String: String] = [:]
        for case let file as URL in enumerator where file.pathExtension == "sumi" {
            templates[templateKey(file)] = try String(contentsOf: file, encoding: .utf8)
        }
        return templates
    }

    static func loadLegacyTemplatePaths(root: URL, config: SumiConfig) throws -> Set<String> {
        let themeDir = themeRoot(root: root, config: config)
        guard FileManager.default.fileExists(atPath: themeDir.path),
              let enumerator = FileManager.default.enumerator(at: themeDir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }
        var paths = Set<String>()
        for case let file as URL in enumerator where file.pathExtension == "liquid" {
            paths.insert(templateKey(file))
        }
        return paths
    }

    static func themeRoot(root: URL, config: SumiConfig) -> URL {
        root.appendingPathComponent(config.theme?.path ?? "theme")
    }

    static func templateKey(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    func templateKey(_ url: URL) -> String {
        ThemeRenderer.templateKey(url)
    }

    func mergedRenderResult(_ first: SumiRenderResult, _ second: SumiRenderResult) -> SumiRenderResult {
        var state = first.state
        for (key, value) in second.state {
            state[key] = value
        }
        return SumiRenderResult(
            html: second.html,
            requiresRuntime: first.requiresRuntime || second.requiresRuntime,
            state: state,
            styles: second.styles + first.styles,
            scripts: second.scripts + first.scripts,
            navigation: second.navigation + first.navigation
        )
    }
}
