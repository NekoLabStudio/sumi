import Foundation

/// The single definition of how a scoped `@style` block's identifier is derived.
/// Because the renderer and the CSS scoping compute the scope the same way from
/// the same declaration, the scoped CSS and the scope attribute in the emitted
/// HTML always agree.
enum SumiScope {
    /// Deterministic FNV-1a hash of a declaration's identity.
    static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100_0000_01b3
        }
        return String(format: "%016llx", hash)
    }

    /// The scope id for a scoped `@style`, e.g. `sumi-a1b2c3d4e5f6a7b8`.
    static func styleScope(
        sourceName: String?, context: SumiSourceContext?, css: String?, file: String?
    ) -> String {
        let key = [
            sourceName ?? "",
            context.map { "\($0.line):\($0.column)" } ?? "",
            css ?? "",
            file ?? "",
        ].joined(separator: "|")
        return "sumi-\(stableHash(key))"
    }

    /// The scope id for a scoped `@script`.
    static func scriptScope(
        sourceName: String?, context: SumiSourceContext?, js: String?, file: String?,
        language: SumiScriptLanguage
    ) -> String {
        let key = [
            "script",
            sourceName ?? "",
            context.map { "\($0.line):\($0.column)" } ?? "",
            js ?? "",
            file ?? "",
            language.rawValue,
        ].joined(separator: "|")
        return "sumi-\(stableHash(key))"
    }

    /// The attribute name carrying a scope id, e.g. `data-sumi-scope-sumi-…`.
    static func attribute(for scope: String) -> String {
        "data-sumi-scope-\(scope)"
    }
}
