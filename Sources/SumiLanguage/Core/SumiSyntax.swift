import Foundation

struct SumiComponent {
    var name: String
    var parameters: [SumiParameter]
    var body: [SumiNode]
    var context: SumiSourceContext?
}

struct SumiParameter {
    var name: String
    var defaultExpression: String?
    /// The declared parameter type, e.g. `Post`, `[Post]`, `User?`, or `nil`
    /// when none is written. The renderer ignores the annotation.
    var typeAnnotation: String?
}

struct SumiArgument {
    var label: String?
    var expression: String
}

struct SumiStyleDeclaration {
    var css: String?
    var file: String?
    var scoped: Bool
    var sourceName: String?
    var context: SumiSourceContext?
}

struct SumiScriptDeclaration {
    var js: String?
    var file: String?
    var language: SumiScriptLanguage
    var scoped: Bool
    var sourceName: String?
    var context: SumiSourceContext?
}

struct SumiNavigationDeclaration {
    var resource: SumiNavigationResource
    var context: SumiSourceContext?
}

struct SumiImageDeclaration {
    var arguments: [SumiArgument]
    var context: SumiSourceContext?
}

enum SumiNode {
    case text(String)
    case output(String, SumiSourceContext?)
    case style(SumiStyleDeclaration)
    case script(SumiScriptDeclaration)
    case navigation(SumiNavigationDeclaration)
    case image(SumiImageDeclaration)
    case state(name: String, expression: String, context: SumiSourceContext?)
    case assign(name: String, expression: String, context: SumiSourceContext?)
    case loop(variable: String, collection: String, body: [SumiNode], context: SumiSourceContext?)
    case conditional(condition: String, body: [SumiNode], alternate: [SumiNode], context: SumiSourceContext?)
    case slot(name: String?, fallback: [SumiNode], context: SumiSourceContext?)
    case content(name: String, body: [SumiNode], context: SumiSourceContext?)
    case componentDefinition(SumiComponent)
    case componentCall(name: String, arguments: [SumiArgument], body: [SumiNode], context: SumiSourceContext?)
}
