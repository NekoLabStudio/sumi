import Foundation
import PackagePlugin

@main
struct SumiAssetsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let tool = try context.tool(named: "SumiAssets")
        let packageDirectory = context.package.directoryURL
        let output = context.pluginWorkDirectoryURL.appendingPathComponent("GeneratedSumiAssets.swift")

        let assets: [(name: String, path: String)] = [
            ("defaultThemeLayoutSumi", "Sources/Sumi/Templates/DefaultTheme/layout.sumi"),
            ("defaultThemeHomeSumi", "Sources/Sumi/Templates/DefaultTheme/home.sumi"),
            ("defaultThemeCategorySumi", "Sources/Sumi/Templates/DefaultTheme/category.sumi"),
            ("defaultThemePostSumi", "Sources/Sumi/Templates/DefaultTheme/post.sumi"),
            ("defaultThemePageSumi", "Sources/Sumi/Templates/DefaultTheme/page.sumi"),
            ("defaultThemeNotFoundSumi", "Sources/Sumi/Templates/DefaultTheme/404.sumi"),
            ("defaultThemeFeedXMLSumi", "Sources/Sumi/Templates/DefaultTheme/feed.xml.sumi"),
            ("defaultThemeFeedJSONSumi", "Sources/Sumi/Templates/DefaultTheme/feed.json.sumi"),
            ("defaultComponentCategoriesSumi", "Sources/Sumi/Templates/DefaultTheme/components/Categories.sumi"),
            ("defaultComponentPaginationSumi", "Sources/Sumi/Templates/DefaultTheme/components/Pagination.sumi"),
            ("defaultComponentPostCardSumi", "Sources/Sumi/Templates/DefaultTheme/components/PostCard.sumi"),
            ("defaultComponentPostListSumi", "Sources/Sumi/Templates/DefaultTheme/components/PostList.sumi"),
            ("defaultComponentSiteFooterSumi", "Sources/Sumi/Templates/DefaultTheme/components/SiteFooter.sumi"),
            ("defaultComponentSiteHeaderSumi", "Sources/Sumi/Templates/DefaultTheme/components/SiteHeader.sumi"),
            ("defaultComponentSiteStylesSumi", "Sources/Sumi/Templates/DefaultTheme/components/SiteStyles.sumi"),
            ("defaultComponentSyndicationLinksSumi", "Sources/Sumi/Templates/DefaultTheme/components/SyndicationLinks.sumi")
        ]

        // The guides go in too, so `sumi mcp` can answer from the docs of the
        // exact version that is running. Unreleased notes stay out.
        let docsDirectory = packageDirectory.appendingPathComponent("docs")
        let docs = (FileManager.default.enumerator(atPath: docsDirectory.path)?.allObjects as? [String] ?? [])
            .filter { $0.hasSuffix(".md") && $0 != "upgrading/next.md" }
            .sorted()

        let inputs = assets.map { packageDirectory.appendingPathComponent($0.path) }
            + docs.map { docsDirectory.appendingPathComponent($0) }
        let arguments = ["--output", output.path]
            + zip(assets, inputs).map { asset, input in "\(asset.name)=\(input.path)" }
            + docs.flatMap { ["--doc", "\($0)=\(docsDirectory.appendingPathComponent($0).path)"] }

        return [
            .buildCommand(
                displayName: "Generate Sumi assets",
                executable: tool.url,
                arguments: arguments,
                inputFiles: inputs,
                outputFiles: [output]
            )
        ]
    }
}
