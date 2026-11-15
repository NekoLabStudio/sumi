import Foundation

public struct SumiSourceContext: Equatable, Sendable {
    public var sourceName: String?
    public var line: Int
    public var column: Int
    public var sourceLine: String

    public var description: String {
        let location = [sourceName, "\(line):\(column)"].compactMap { $0 }.joined(separator: ":")
        return sourceLine.isEmpty ? location : "\(location)\n\(sourceLine)\n\(String(repeating: " ", count: max(0, column - 1)))^"
    }
}

public struct SumiTemplateError: Error, CustomStringConvertible, Equatable {
    public var message: String
    public var context: SumiSourceContext?

    public static func template(_ message: String, context: SumiSourceContext? = nil) -> SumiTemplateError {
        SumiTemplateError(message: message, context: context)
    }

    public var description: String {
        guard let context else { return message }
        return "\(message)\n\(context.description)"
    }

    func withContext(_ context: SumiSourceContext?) -> SumiTemplateError {
        guard self.context == nil else { return self }
        return SumiTemplateError(message: message, context: context)
    }
}

public struct SumiSafeHTML: Equatable, CustomStringConvertible {
    public var html: String

    public init(_ html: String) {
        self.html = html
    }

    public var description: String { html }
}

public struct SumiFunctionCall {
    public var arguments: [Any?]
    public var namedArguments: [String: Any?]
    public var context: SumiSourceContext?

    public init(arguments: [Any?], namedArguments: [String: Any?] = [:], context: SumiSourceContext? = nil) {
        self.arguments = arguments
        self.namedArguments = namedArguments
        self.context = context
    }
}

public struct SumiFunction {
    private let body: (SumiFunctionCall) throws -> Any?

    public init(_ body: @escaping (SumiFunctionCall) throws -> Any?) {
        self.body = body
    }

    public func call(_ call: SumiFunctionCall) throws -> Any? {
        try body(call)
    }
}

public struct SumiStyleResource: Equatable {
    public var css: String?
    public var file: String?
    public var scoped: Bool
    public var scope: String?
    public var sourceName: String?

    public init(css: String? = nil, file: String? = nil, scoped: Bool = false, scope: String? = nil, sourceName: String? = nil) {
        self.css = css
        self.file = file
        self.scoped = scoped
        self.scope = scope
        self.sourceName = sourceName
    }

    public var scopeAttribute: String? {
        guard let scope else { return nil }
        return "data-sumi-scope-\(scope)"
    }
}

public enum SumiScriptLanguage: String, Equatable {
    case javascript
    case sumi
}

public struct SumiScriptResource: Equatable {
    public var js: String?
    public var file: String?
    public var language: SumiScriptLanguage
    public var scoped: Bool
    public var scope: String?
    public var sourceName: String?
    public var context: SumiSourceContext?

    public init(js: String? = nil, file: String? = nil, language: SumiScriptLanguage = .sumi, scoped: Bool = false, scope: String? = nil, sourceName: String? = nil, context: SumiSourceContext? = nil) {
        self.js = js
        self.file = file
        self.language = language
        self.scoped = scoped
        self.scope = scope
        self.sourceName = sourceName
        self.context = context
    }

    public var scopeAttribute: String? {
        guard let scope else { return nil }
        return "data-sumi-scope-\(scope)"
    }
}

public struct SumiNavigationHook: Equatable {
    public var name: String
    public var actions: [String]

    public init(name: String, actions: [String]) {
        self.name = name
        self.actions = actions
    }
}

public struct SumiNavigationResource: Equatable {
    public var root: String
    public var viewTransitions: Bool
    public var scroll: String
    public var minimumDuration: Int
    public var progressBar: Bool
    public var progressBarDelay: Int
    public var hooks: [SumiNavigationHook]

    public init(root: String = "body", viewTransitions: Bool = true, scroll: String = "top", minimumDuration: Int = 0, progressBar: Bool = true, progressBarDelay: Int = 500, hooks: [SumiNavigationHook] = []) {
        self.root = root
        self.viewTransitions = viewTransitions
        self.scroll = scroll
        self.minimumDuration = minimumDuration
        self.progressBar = progressBar
        self.progressBarDelay = progressBarDelay
        self.hooks = hooks
    }
}

public struct SumiResourceArgument: Equatable {
    public var label: String?
    public var expression: String

    public init(label: String? = nil, expression: String) {
        self.label = label
        self.expression = expression
    }
}

public struct SumiAssetReference: Equatable {
    public var path: String?
    public var expression: String
    public var sourceName: String?
    public var context: SumiSourceContext?

    public init(path: String?, expression: String, sourceName: String? = nil, context: SumiSourceContext? = nil) {
        self.path = path
        self.expression = expression
        self.sourceName = sourceName
        self.context = context
    }
}

public struct SumiImageReference: Equatable {
    public var src: String?
    public var arguments: [SumiResourceArgument]
    public var sourceName: String?
    public var context: SumiSourceContext?

    public init(src: String?, arguments: [SumiResourceArgument], sourceName: String? = nil, context: SumiSourceContext? = nil) {
        self.src = src
        self.arguments = arguments
        self.sourceName = sourceName
        self.context = context
    }

    public var altExpression: String? {
        arguments.first { $0.label == "alt" }?.expression
    }
}

public struct SumiRenderResult {
    public var html: String
    public var requiresRuntime: Bool
    public var state: [String: Any]
    public var styles: [SumiStyleResource]
    public var scripts: [SumiScriptResource]
    public var navigation: [SumiNavigationResource]

    public init(html: String, requiresRuntime: Bool, state: [String: Any], styles: [SumiStyleResource] = [], scripts: [SumiScriptResource] = [], navigation: [SumiNavigationResource] = []) {
        self.html = html
        self.requiresRuntime = requiresRuntime
        self.state = state
        self.styles = styles
        self.scripts = scripts
        self.navigation = navigation
    }
}

public struct SumiCheckResult {
    public var styles: [SumiStyleResource]
    public var scripts: [SumiScriptResource]
    public var navigation: [SumiNavigationResource]
    public var assets: [SumiAssetReference]
    public var images: [SumiImageReference]

    public init(styles: [SumiStyleResource], scripts: [SumiScriptResource] = [], navigation: [SumiNavigationResource] = [], assets: [SumiAssetReference] = [], images: [SumiImageReference] = []) {
        self.styles = styles
        self.scripts = scripts
        self.navigation = navigation
        self.assets = assets
        self.images = images
    }
}
