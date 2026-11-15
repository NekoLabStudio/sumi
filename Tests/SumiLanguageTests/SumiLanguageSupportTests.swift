import XCTest
@testable import SumiLanguage

final class SumiLanguageSupportTests: XCTestCase {
    func testDiagnosticsReportSumiSyntaxErrorsWithLocation() {
        let diagnostics = SumiLanguageSupport.diagnostics(
            for: """
            @if site.title {
              <h1>{site.title}</h1>
            """,
            sourceName: "theme/home.sumi"
        )

        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics.first?.sourceName, "theme/home.sumi")
        XCTAssertTrue(diagnostics.first?.message.contains("Missing closing }") == true)
    }

    func testDiagnosticsUseComponentSources() {
        let diagnostics = SumiLanguageSupport.diagnostics(
            for: """
            @Card("Hello", title: "Duplicate")
            """,
            sourceName: "theme/home.sumi",
            componentSources: [
                "theme/components/Card.sumi": """
                @component Card(title) {
                  <article>{title}</article>
                }
                """
            ]
        )

        XCTAssertEqual(diagnostics.first?.message, "Duplicate argument title for component Card.")
        XCTAssertEqual(diagnostics.first?.line, 1)
    }

    func testDiagnosticsCompileInlineSumiScripts() {
        let diagnostics = SumiLanguageSupport.diagnostics(
            for: """
            @script {
              let menu = page.query("#menu")
              menu.fly()
            }
            """,
            sourceName: "theme/home.sumi"
        )

        XCTAssertEqual(diagnostics.first?.message, "Unsupported Sumi script method fly.")
        XCTAssertEqual(diagnostics.first?.line, 3)
    }

    func testCompletionsIncludeDirectivesAndContextValues() {
        let labels = Set(SumiLanguageSupport.completions().map(\.label))

        XCTAssertTrue(labels.contains("@component"))
        XCTAssertTrue(labels.contains("@navigation"))
        XCTAssertTrue(labels.contains("site"))
        XCTAssertTrue(labels.contains("class:"))
    }

    func testDocumentSymbolsFindComponentsStateAndResources() {
        let symbols = SumiLanguageSupport.symbols(in: """
        @component Card(title) {
          <article>{title}</article>
        }
        @state expanded = false
        @style(scoped) {
          .card { color: red; }
        }
        @script {
          expanded.toggle()
        }
        """)

        XCTAssertTrue(symbols.contains { $0.name == "Card" && $0.detail == "component" })
        XCTAssertTrue(symbols.contains { $0.name == "expanded" && $0.detail == "state" })
        XCTAssertTrue(symbols.contains { $0.name == "style" && $0.detail == "style" })
        XCTAssertTrue(symbols.contains { $0.name == "script" && $0.detail == "script" })
    }
}
