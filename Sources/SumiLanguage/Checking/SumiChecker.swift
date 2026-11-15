import Foundation

struct SumiChecker {
    private let components: [String: SumiComponent]
    private var styles: [SumiStyleResource] = []
    private var scripts: [SumiScriptResource] = []
    private var navigation: [SumiNavigationResource] = []
    private var assets: [SumiAssetReference] = []
    private var images: [SumiImageReference] = []

    init(components: [String: SumiComponent]) {
        self.components = components
    }

    mutating func check(_ nodes: [SumiNode]) throws -> SumiCheckResult {
        try checkNodes(nodes)
        return SumiCheckResult(styles: styles, scripts: scripts, navigation: navigation, assets: assets, images: images)
    }

    private mutating func checkNodes(_ nodes: [SumiNode]) throws {
        for node in nodes {
            try checkNode(node)
        }
    }

    private mutating func checkNode(_ node: SumiNode) throws {
        switch node {
        case .text, .assign, .state:
            return
        case .output(let expression, let context):
            assets.append(contentsOf: SumiExpressionInspector.assetReferences(in: expression, context: context))
        case .image(let declaration):
            images.append(SumiImageReference(
                src: SumiExpressionInspector.imageSource(in: declaration.arguments),
                arguments: declaration.arguments.map { SumiResourceArgument(label: $0.label, expression: $0.expression) },
                sourceName: declaration.context?.sourceName,
                context: declaration.context
            ))
        case .style(let declaration):
            styles.append(SumiStyleResource(
                css: declaration.css,
                file: declaration.file,
                scoped: declaration.scoped,
                sourceName: declaration.sourceName
            ))
        case .script(let declaration):
            scripts.append(SumiScriptResource(
                js: declaration.js,
                file: declaration.file,
                language: declaration.language,
                scoped: declaration.scoped,
                sourceName: declaration.sourceName,
                context: declaration.context
            ))
        case .navigation(let declaration):
            navigation.append(declaration.resource)
        case .loop(_, _, let body, _):
            try checkNodes(body)
        case .conditional(_, let body, let alternate, _):
            try checkNodes(body)
            try checkNodes(alternate)
        case .slot(_, let fallback, _):
            try checkNodes(fallback)
        case .content(_, _, let context):
            throw SumiTemplateError.template("@content can only be used directly inside a component call.", context: context)
        case .componentDefinition(let component):
            try checkNodes(component.body)
        case .componentCall(let name, let arguments, let body, let context):
            try checkComponentCall(name: name, arguments: arguments, context: context)
            try checkComponentCallBody(body)
        }
    }

    private mutating func checkComponentCallBody(_ body: [SumiNode]) throws {
        for node in body {
            if case .content(_, let contentBody, _) = node {
                try checkNodes(contentBody)
            } else {
                try checkNode(node)
            }
        }
    }

    private func checkComponentCall(name: String, arguments: [SumiArgument], context: SumiSourceContext?) throws {
        guard let component = components[name] else {
            throw SumiTemplateError.template("Unknown Sumi component: \(name).\(suggestion(for: name, in: Array(components.keys)))", context: context)
        }
        var positionalIndex = 0
        var assigned = Set<String>()
        let parameters = component.parameters.map(\.name)
        let parameterNames = Set(parameters)

        for argument in arguments {
            if let label = argument.label {
                guard parameterNames.contains(label) else {
                    throw SumiTemplateError.template("Unknown argument \(label) for component \(component.name).\(suggestion(for: label, in: Array(parameterNames)))", context: context)
                }
                guard assigned.insert(label).inserted else {
                    throw SumiTemplateError.template("Duplicate argument \(label) for component \(component.name).", context: context)
                }
            } else {
                guard positionalIndex < parameters.count else {
                    throw SumiTemplateError.template("Too many arguments for component \(component.name).", context: context)
                }
                assigned.insert(parameters[positionalIndex])
                positionalIndex += 1
            }
        }
    }

    private func suggestion(for value: String, in candidates: [String]) -> String {
        SumiScanning.suggestion(for: value, in: candidates)
    }
}
