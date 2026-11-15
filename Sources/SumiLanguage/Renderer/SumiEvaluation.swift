import Foundation

struct SumiEvaluation {
    var value: Any?
    var raw: Bool
}

struct SumiAction: CustomStringConvertible {
    var expression: String
    var description: String { expression }
}

struct SumiBinding {
    var expression: String
    var rendered: String
    var action: Bool
}

struct SumiFragment {
    var html = ""
    var scopes: [String] = []

    mutating func append(_ html: String) {
        self.html += html
    }

    mutating func append(_ fragment: SumiFragment) {
        html += fragment.html
        scopes.append(contentsOf: fragment.scopes)
    }
}
