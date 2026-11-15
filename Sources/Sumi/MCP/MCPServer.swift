import Foundation

/// `sumi mcp`: a Model Context Protocol server over stdio that gives AI coding
/// agents accurate Sumi knowledge while they work on a site. It speaks
/// newline-delimited JSON-RPC 2.0 and exposes three tools:
///
/// - `docs_page(page)`: a whole guide, such as `templates/syntax`, from the docs
///   embedded in this binary, so it matches the Sumi version that is running.
/// - `search_docs(query)`: matching sections across those guides.
/// - `site_info()`: the current site's `sumi.json`.
///
/// Point an agent at it from a site with `{"command": "./sumi", "args": ["mcp"]}`.
public enum MCPServer {
    public static func run(root: URL) {
        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = respond(to: message, root: root),
                  let output = try? JSONSerialization.data(withJSONObject: response) else {
                continue
            }
            FileHandle.standardOutput.write(output)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }

    /// The reply to one JSON-RPC message, or nil for a notification.
    static func respond(to message: [String: Any], root: URL) -> [String: Any]? {
        let id = message["id"]
        let method = message["method"] as? String ?? ""
        switch method {
        case "initialize":
            return result(id: id, [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "sumi", "version": SumiMetadata.currentVersion],
                "instructions": "Sumi builds static sites from Markdown with themes written in Sumi templates (.sumi files). Read the relevant guide with docs_page or search_docs before changing a site's templates or sumi.json."
            ])
        case "notifications/initialized", "notifications/cancelled":
            return nil
        case "ping":
            return result(id: id, [:])
        case "tools/list":
            return result(id: id, ["tools": toolDefinitions])
        case "tools/call":
            let params = message["params"] as? [String: Any] ?? [:]
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            let text: String
            switch params["name"] as? String ?? "" {
            case "docs_page":
                text = docsPage(arguments["page"] as? String ?? "")
            case "search_docs":
                text = searchDocs(query: arguments["query"] as? String ?? "")
            case "site_info":
                text = siteInfo(root: root)
            default:
                return error(id: id, code: -32602, message: "Unknown tool: \(params["name"] as? String ?? "")")
            }
            return result(id: id, ["content": [["type": "text", "text": text]]])
        default:
            return id == nil ? nil : error(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    // MARK: - Tools

    private static var toolDefinitions: [[String: Any]] {
        [
            [
                "name": "docs_page",
                "description": "One Sumi guide in full. Pages: \(pageNames.joined(separator: ", ")).",
                "inputSchema": [
                    "type": "object",
                    "properties": ["page": ["type": "string", "description": "A page name, such as templates/syntax."]],
                    "required": ["page"]
                ]
            ],
            [
                "name": "search_docs",
                "description": "Search the Sumi guides and return matching sections.",
                "inputSchema": [
                    "type": "object",
                    "properties": ["query": ["type": "string"]],
                    "required": ["query"]
                ]
            ],
            [
                "name": "site_info",
                "description": "The current site's sumi.json: its theme, content folders, publishing, CI and syndication settings.",
                "inputSchema": ["type": "object", "properties": [String: Any]()]
            ]
        ]
    }

    /// Guide names as the docs site shows them: `templates/syntax`, `deployment`.
    static var pageNames: [String] {
        GeneratedSumiAssets.documentation.keys.map { name in
            let page = String(name.dropLast(".md".count))
            return page.hasSuffix("/index") ? String(page.dropLast("/index".count)) : page
        }.sorted()
    }

    static func docsPage(_ page: String) -> String {
        let name = page.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")).replacingOccurrences(of: ".md", with: "")
        if let content = GeneratedSumiAssets.documentation["\(name).md"] ?? GeneratedSumiAssets.documentation["\(name)/index.md"] {
            return content
        }
        return "Unknown page '\(page)'. Pages: \(pageNames.joined(separator: ", "))."
    }

    static func searchDocs(query: String) -> String {
        let terms = query.lowercased().split(separator: " ").map(String.init)
        guard let first = terms.first else { return "No matches." }
        var hits: [String] = []
        for (name, content) in GeneratedSumiAssets.documentation.sorted(by: { $0.key < $1.key }) {
            let lowered = content.lowercased()
            guard terms.allSatisfy({ lowered.contains($0) }),
                  let range = content.range(of: first, options: .caseInsensitive) else { continue }
            // Slice the original text around the match, case-insensitively, so a
            // character whose lowercase form has a different length can't mis-slice.
            let start = content.index(range.lowerBound, offsetBy: -80, limitedBy: content.startIndex) ?? content.startIndex
            let end = content.index(range.upperBound, offsetBy: 240, limitedBy: content.endIndex) ?? content.endIndex
            hits.append("## docs/\(name)\n\n…\(content[start..<end].trimmingCharacters(in: .whitespacesAndNewlines))…")
            if hits.count >= 6 { break }
        }
        return hits.isEmpty ? "No docs matched '\(query)'." : hits.joined(separator: "\n\n")
    }

    static func siteInfo(root: URL) -> String {
        guard let config = try? String(contentsOf: root.appendingPathComponent(SumiMetadata.configFileName), encoding: .utf8) else {
            return "No \(SumiMetadata.configFileName) here. Run sumi mcp from a Sumi site's folder."
        }
        return "This site's \(SumiMetadata.configFileName):\n\n```json\n\(config)\n```"
    }

    // MARK: - JSON-RPC

    private static func result(id: Any?, _ result: [String: Any]) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id ?? NSNull(), "result": result]
    }

    private static func error(id: Any?, code: Int, message: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id ?? NSNull(), "error": ["code": code, "message": message]]
    }
}
