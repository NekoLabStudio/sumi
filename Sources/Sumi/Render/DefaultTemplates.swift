enum DefaultTemplates {
    static let names = GeneratedSumiAssets.defaultTemplateNames

    static func fileName(for name: String) -> String {
        "\(name).sumi"
    }

    static func organizedFileName(for name: String) -> String {
        if name == "layout" {
            return "layouts/default.sumi"
        }
        return "pages/\(name).sumi"
    }

    static let templates = GeneratedSumiAssets.defaultTemplates
    static let components = GeneratedSumiAssets.defaultTemplateComponents
}
