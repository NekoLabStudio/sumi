import Foundation

public enum ConfigLoader {
    public static func load(root: URL) throws -> SumiConfig {
        let jsonURL = root.appendingPathComponent(SumiMetadata.configFileName)
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            let data = try Data(contentsOf: jsonURL)
            return try validateVersion(decode(data, file: SumiMetadata.configFileName))
        }

        let tsURL = root.appendingPathComponent("site.config.ts")
        guard FileManager.default.fileExists(atPath: tsURL.path) else {
            throw SumiError.config("\(SumiMetadata.configFileName) or site.config.ts was not found.")
        }
        let source = try String(contentsOf: tsURL, encoding: .utf8)
        return try loadTypeScriptConfig(source)
    }

    /// Returns nil when no config file exists in `root`; throws when a config file exists but cannot be loaded.
    public static func loadIfPresent(root: URL) throws -> SumiConfig? {
        let candidates = [SumiMetadata.configFileName, "site.config.ts"]
        guard candidates.contains(where: { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }) else {
            return nil
        }
        return try load(root: root)
    }

    /// The config as Sumi writes it to `sumi.json`.
    public static func encode(_ config: SumiConfig) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(config), as: UTF8.self) + "\n"
    }

    public static func loadTypeScriptConfig(_ source: String) throws -> SumiConfig {
        let literal = try extractDefineConfigLiteral(source)
        var parsed = try TypeScriptLiteralParser(literal).parse()
        // A TypeScript config predates sumi.json, where the Inkstead app's
        // `connection` section is called `inkstead`.
        if var object = parsed as? [String: Any], let connection = object.removeValue(forKey: "connection") {
            object["inkstead"] = connection
            parsed = object
        }
        let data = try JSONSerialization.data(withJSONObject: parsed, options: [])
        return try validateVersion(decode(data, file: "site.config.ts"))
    }

    private static func decode(_ data: Data, file: String) throws -> SumiConfig {
        do {
            return try JSONDecoder().decode(SumiConfig.self, from: data)
        } catch let error as DecodingError {
            throw SumiError.config("\(file): \(describe(error))")
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        let context: DecodingError.Context?
        switch error {
        case .typeMismatch(_, let value), .valueNotFound(_, let value), .keyNotFound(_, let value), .dataCorrupted(let value):
            context = value
        @unknown default:
            context = nil
        }
        guard let context else { return String(describing: error) }
        let path = context.codingPath.map { key in
            key.intValue.map { "[\($0)]" } ?? key.stringValue
        }.joined(separator: ".")
        return path.isEmpty ? context.debugDescription : "\(path): \(context.debugDescription)"
    }

    private static func validateVersion(_ config: SumiConfig) throws -> SumiConfig {
        let version = config.recordedVersion
        guard SumiVersion(version) <= SumiVersion(SumiMetadata.currentVersion) else {
            throw SumiError.config("This site was created with Sumi \(version). Install a newer Sumi binary before building or migrating it.")
        }
        return config
    }

    private static func extractDefineConfigLiteral(_ source: String) throws -> String {
        guard let callRange = source.range(of: "defineConfig") else {
            throw SumiError.config("defineConfig(...) was not found.")
        }
        guard let openIndex = source[callRange.upperBound...].firstIndex(of: "(") else {
            throw SumiError.config("defineConfig(...) is missing its opening parenthesis.")
        }

        var depth = 0
        var inString: Character?
        var escape = false
        var closeIndex: String.Index?
        var index = openIndex
        while index < source.endIndex {
            let char = source[index]
            if let quote = inString {
                if escape {
                    escape = false
                } else if char == "\\" {
                    escape = true
                } else if char == quote {
                    inString = nil
                }
            } else if char == "\"" || char == "'" {
                inString = char
            } else if char == "(" {
                depth += 1
            } else if char == ")" {
                depth -= 1
                if depth == 0 {
                    closeIndex = index
                    break
                }
            }
            index = source.index(after: index)
        }
        guard let closeIndex else {
            throw SumiError.config("defineConfig(...) is missing its closing parenthesis.")
        }
        return String(source[source.index(after: openIndex)..<closeIndex])
    }
}

private final class TypeScriptLiteralParser {
    private let input: [Character]
    private var index = 0

    init(_ source: String) {
        input = Array(source)
    }

    func parse() throws -> Any {
        skipTrivia()
        let value = try parseValue()
        skipTrivia()
        return value
    }

    private func parseValue() throws -> Any {
        skipTrivia()
        guard let char = peek() else {
            throw error("Unexpected end of config literal.")
        }
        if char == "{" { return try parseObject() }
        if char == "[" { return try parseArray() }
        if char == "\"" || char == "'" { return try parseString() }
        if char == "-" || char.isNumber { return try parseNumber() }
        let identifier = try parseIdentifier()
        switch identifier {
        case "true": return true
        case "false": return false
        case "null", "undefined": return NSNull()
        default:
            return identifier
        }
    }

    private func parseObject() throws -> [String: Any] {
        try consume("{")
        var object: [String: Any] = [:]
        while true {
            skipTrivia()
            if try consumeIf("}") { return object }
            let key = try parseKey()
            skipTrivia()
            try consume(":")
            object[key] = try parseValue()
            skipTrivia()
            if try consumeIf(",") { continue }
            try consume("}")
            return object
        }
    }

    private func parseArray() throws -> [Any] {
        try consume("[")
        var array: [Any] = []
        while true {
            skipTrivia()
            if try consumeIf("]") { return array }
            array.append(try parseValue())
            skipTrivia()
            if try consumeIf(",") { continue }
            try consume("]")
            return array
        }
    }

    private func parseKey() throws -> String {
        skipTrivia()
        guard let char = peek() else {
            throw error("Unexpected end while reading object key.")
        }
        if char == "\"" || char == "'" { return try parseString() }
        return try parseIdentifier()
    }

    private func parseString() throws -> String {
        guard let quote = peek(), quote == "\"" || quote == "'" else {
            throw error("Expected string literal.")
        }
        index += 1
        var output = ""
        var escape = false
        while let char = peek() {
            index += 1
            if escape {
                switch char {
                case "n": output.append("\n")
                case "r": output.append("\r")
                case "t": output.append("\t")
                default: output.append(char)
                }
                escape = false
            } else if char == "\\" {
                escape = true
            } else if char == quote {
                return output
            } else {
                output.append(char)
            }
        }
        throw error("Unterminated string literal.")
    }

    private func parseNumber() throws -> Any {
        let start = index
        if peek() == "-" { index += 1 }
        while peek()?.isNumber == true { index += 1 }
        if peek() == "." {
            index += 1
            while peek()?.isNumber == true { index += 1 }
        }
        let raw = String(input[start..<index])
        if let int = Int(raw) { return int }
        if let double = Double(raw) { return double }
        throw error("Invalid number literal \(raw).")
    }

    private func parseIdentifier() throws -> String {
        skipTrivia()
        let start = index
        while let char = peek(), char.isLetter || char.isNumber || char == "_" || char == "-" {
            index += 1
        }
        if start == index {
            throw error("Expected identifier.")
        }
        return String(input[start..<index])
    }

    private func skipTrivia() {
        while true {
            if let char = peek(), char.isWhitespace {
                index += 1
                continue
            }
            if peek() == "/", peek(ahead: 1) == "/" {
                while let char = peek(), char != "\n" { index += 1 }
                continue
            }
            if peek() == "/", peek(ahead: 1) == "*" {
                index += 2
                while index < input.count, !(peek() == "*" && peek(ahead: 1) == "/") { index += 1 }
                index = min(index + 2, input.count)
                continue
            }
            break
        }
    }

    private func consume(_ expected: Character) throws {
        skipTrivia()
        guard peek() == expected else {
            throw error("Expected \(expected).")
        }
        index += 1
    }

    private func error(_ message: String) -> SumiError {
        var line = 1
        var column = 1
        for char in input[..<min(index, input.count)] {
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }
        return .parse("\(message) (line \(line), column \(column) of the defineConfig literal)")
    }

    private func consumeIf(_ expected: Character) throws -> Bool {
        skipTrivia()
        if peek() == expected {
            index += 1
            return true
        }
        return false
    }

    private func peek(ahead: Int = 0) -> Character? {
        let target = index + ahead
        guard target < input.count else { return nil }
        return input[target]
    }
}
