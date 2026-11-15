import Foundation

struct SumiRenderer {
    let root: [String: Any]
    let components: [String: SumiComponent]
    var locals: [String: Any] = [:]
    var scopes: [[String: Any]] = []
    var stateNames = Set<String>()
    var stateValues: [String: Any] = [:]
    var bindings: [String: SumiBinding] = [:]
    var nextBindingID = 0
    var componentDepth = 0
    var styles: [SumiStyleResource] = []
    var scripts: [SumiScriptResource] = []
    var navigation: [SumiNavigationResource] = []
    var evaluationContext: SumiSourceContext?

    init(context: [String: Any], components: [String: SumiComponent]) {
        root = context
        self.components = components
    }

    mutating func renderDocument(_ nodes: [SumiNode]) throws -> SumiRenderResult {
        let fragment = try render(nodes)
        let rendered = addScopeAttributes(fragment.html, scopes: fragment.scopes)
        let html = try renderAttributeHelpers(rendered)
        return SumiRenderResult(html: html, requiresRuntime: requiresSumiRuntime(html) || !navigation.isEmpty, state: stateValues, styles: styles, scripts: scripts, navigation: navigation)
    }

    mutating func render(_ nodes: [SumiNode]) throws -> SumiFragment {
        var output = SumiFragment()
        for node in nodes {
            switch node {
            case .text(let text):
                output.append(text)
            case .output(let expression, let context):
                output.append(try located(context) { try renderOutput(expression, context: context) })
            case .style(let declaration):
                try located(declaration.context) {
                    if let scope = try registerStyle(declaration) {
                        output.scopes.append(scope)
                    }
                }
            case .script(let declaration):
                try located(declaration.context) {
                    if let scope = try registerScript(declaration) {
                        output.scopes.append(scope)
                    }
                }
            case .navigation(let declaration):
                try located(declaration.context) {
                    registerNavigation(declaration)
                }
            case .image(let declaration):
                output.append(try located(declaration.context) { try renderImage(declaration) })
            case .state(let name, let expression, let context):
                try located(context) {
                    let value = try evaluateExpression(expression, context: context).value ?? NSNull()
                    stateNames.insert(name)
                    stateValues[name] = value
                    set(name, to: value)
                }
            case .assign(let name, let expression, let context):
                try located(context) {
                    set(name, to: try evaluateExpression(expression, context: context).value ?? NSNull())
                }
            case .loop(let variable, let collection, let body, let context):
                let collectionValue = try located(context) { try evaluate(collection, context: context) }
                guard let values = collectionValue as? [Any] else { continue }
                for (index, value) in values.enumerated() {
                    scopes.append([
                        variable: value,
                        "forloop": forloop(index: index, count: values.count)
                    ])
                    output.append(try render(body))
                    scopes.removeLast()
                }
            case .conditional(let condition, let body, let alternate, let context):
                output.append(try located(context) {
                    // `@if let name = expr` binds `name` for the body when the
                    // value is non-nil (Swift optional-binding semantics).
                    if let binding = SumiConditionParsing.optionalBinding(in: condition) {
                        let value = try evaluate(binding.expression, context: context)
                        guard !isNilValue(value) else { return try render(alternate) }
                        scopes.append([binding.name: value as Any])
                        defer { scopes.removeLast() }
                        return try render(body)
                    }
                    let passed = try truthy(evaluate(condition, context: context))
                    return try render(passed ? body : alternate)
                })
            case .slot(let name, let fallback, let context):
                output.append(try located(context) { try renderSlot(name: name, fallback: fallback) })
            case .content(_, _, let context):
                throw SumiTemplateError.template("@content can only be used inside a component call.", context: context)
            case .componentDefinition:
                continue
            case .componentCall(let name, let arguments, let body, let context):
                output.append(try located(context) { try renderComponent(name: name, arguments: arguments, body: body, context: context) })
            }
        }
        return output
    }
}
