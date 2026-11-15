import XCTest

@testable import SumiLanguage

final class SumiRegressionTests: XCTestCase {
    func testRecursiveComponentsThrowInsteadOfCrashing() throws {
        let template = try SumiTemplate("""
        @component Loop() {
          @Loop()
        }
        @Loop()
        """)

        XCTAssertThrowsError(try template.render([:])) { error in
            guard let sumiError = error as? SumiTemplateError else {
                return XCTFail("Expected SumiTemplateError, got \(error)")
            }
            XCTAssertTrue(sumiError.message.contains("Loop"))
            XCTAssertTrue(sumiError.message.contains("64"))
            XCTAssertNotNil(sumiError.context)
        }
    }

    func testUnquotedInterpolatedAttributeIsRejected() throws {
        // A value with a space would inject an attribute out of an unquoted value.
        XCTAssertThrowsError(try SumiTemplate("<a href={url}>x</a>")) { error in
            XCTAssertTrue((error as? SumiTemplateError)?.message.contains("Quote") ?? false)
        }
        // Quoted attributes and body text with `=` are fine.
        XCTAssertNoThrow(try SumiTemplate(#"<a href="{url}">x</a>"#))
        XCTAssertNoThrow(try SumiTemplate("<p>2 = {n} today</p>"))
    }

    func testEscapingIncludesSingleQuotes() throws {
        let template = try SumiTemplate(#"<p title="{name}">{name}</p>"#)
        let html = try template.render(["name": "O'Brien & \"Co\" <em>"])

        XCTAssertTrue(html.contains("O&#39;Brien &amp; &quot;Co&quot; &lt;em&gt;"))
        XCTAssertFalse(html.contains("O'Brien"))
    }

    func testEscapeOnceKeepsExistingEntitiesAndEscapesSingleQuotes() throws {
        let template = try SumiTemplate("{text | escape_once}")
        let html = try template.render(["text": "Fish &amp; Chips 'n' &#39; <em> & more"])

        XCTAssertTrue(html.contains("Fish &amp; Chips &#39;n&#39; &#39; &lt;em&gt; &amp; more"))
    }

    func testNumericDoesNotTrapOnHugeDoubles() throws {
        let template = try SumiTemplate("{big | plus(1)}")

        XCTAssertNoThrow(try template.render(["big": 1e19]))
        XCTAssertNoThrow(try template.render(["big": Double.greatestFiniteMagnitude]))
    }

    func testQuotedLiteralsRequireClosingQuoteAtEnd() throws {
        XCTAssertEqual(try SumiTemplate(#"{"a" == "b"}"#).render([:]), "false")
        XCTAssertEqual(try SumiTemplate(#"{"a" == "a"}"#).render([:]), "true")
        XCTAssertEqual(try SumiTemplate(#"{"hello"}"#).render([:]), "hello")
    }

    func testEqualityComparesNumbersNumerically() throws {
        XCTAssertEqual(try SumiTemplate("{1 == 1.0}").render([:]), "true")
        XCTAssertEqual(try SumiTemplate("{1 != 1.0}").render([:]), "false")
        XCTAssertEqual(try SumiTemplate("{count == 10}").render(["count": 10.0]), "true")
        XCTAssertEqual(try SumiTemplate("{1 == 2}").render([:]), "false")
        XCTAssertEqual(try SumiTemplate(#"{name == "x"}"#).render(["name": "x"]), "true")
    }

    func testCommentsAllowUnbalancedQuotes() throws {
        let template = try SumiTemplate("""
        before
        @comment { it's a note }
        after
        """)
        let html = try template.render([:])

        XCTAssertTrue(html.contains("before"))
        XCTAssertTrue(html.contains("after"))
        XCTAssertFalse(html.contains("note"))
    }

    func testDefaultFilterKeepsZero() throws {
        let template = try SumiTemplate("{count | default(5)}")

        XCTAssertEqual(try template.render(["count": 0]), "0")
        XCTAssertEqual(try template.render(["count": 0.0]), "0.0")
        XCTAssertEqual(try template.render([:]), "5")
        XCTAssertEqual(try template.render(["count": ""]), "5")
        XCTAssertEqual(try template.render(["count": false]), "5")
        XCTAssertEqual(try template.render(["count": [Any]()]), "5")

        let json = #"{"zero": 0, "flag": false}"#.data(using: .utf8)!
        let context = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: json) as? [String: Any])
        XCTAssertEqual(try SumiTemplate("{zero | default(5)}").render(context), "0")
        XCTAssertEqual(try SumiTemplate("{flag | default(5)}").render(context), "5")
    }

    func testAttributeHelpersHandleGreaterThanInsideQuotedValues() throws {
        let template = try SumiTemplate("""
        <div data-arrow="a > b" class:on="{visible}">x</div>
        """)
        let html = try template.render(["visible": true])

        XCTAssertTrue(html.contains(#"data-arrow="a > b""#))
        XCTAssertTrue(html.contains(#"class="on""#))
    }

    func testNamespacedAttributesAreNotTreatedAsConditional() throws {
        let template = try SumiTemplate("""
        <section epub:type="chapter" xlink:href="#top" xmlns:epub="http://www.idpf.org/2007/ops">x</section>
        """)
        let html = try template.render([:])

        XCTAssertTrue(html.contains(#"epub:type="chapter""#))
        XCTAssertTrue(html.contains("xlink:href=\"#top\""))
        XCTAssertTrue(html.contains(#"xmlns:epub="http://www.idpf.org/2007/ops""#))
    }

    func testSourceContextReportsLineAndColumn() {
        let parser = SumiParser("first line\nsecond line\nthird line", sourceName: "test.sumi")
        var location = parser.source.startIndex
        var expectedLine = 1
        var expectedColumn = 1
        while true {
            let context = parser.sourceContext(at: location)
            XCTAssertEqual(context.line, expectedLine)
            XCTAssertEqual(context.column, expectedColumn)
            guard location < parser.source.endIndex else { break }
            if parser.source[location] == "\n" {
                expectedLine += 1
                expectedColumn = 1
            } else {
                expectedColumn += 1
            }
            location = parser.source.index(after: location)
        }
        XCTAssertEqual(parser.sourceContext(at: parser.source.startIndex).sourceLine, "first line")

        let diagnostics = SumiLanguageSupport.diagnostics(
            for: "<h1>x</h1>\n<p>y</p>\n@if broken {",
            sourceName: "theme/home.sumi"
        )
        XCTAssertEqual(diagnostics.first?.line, 3)
    }

    func testScanningHelpersPreserveCallSiteBehaviour() {
        XCTAssertEqual(
            SumiScanning.splitExpression(
                "a || b | upcase", separator: "|", skippingLogicalPipes: true),
            ["a || b", "upcase"])
        XCTAssertEqual(
            SumiScanning.splitExpression("a || b", separator: "|"),
            ["a", "", "b"])
        XCTAssertEqual(
            SumiScanning.splitExpression(#"f("x,y"), [1, 2], z"#, separator: ","),
            [#"f("x,y")"#, "[1, 2]", "z"])
        XCTAssertNil(SumiScanning.topLevelIndex(of: ":", in: #""a:b""#))
        XCTAssertNotNil(SumiScanning.topLevelIndex(of: ":", in: #"label: value"#))
        XCTAssertEqual(SumiScanning.levenshtein("kitten", "sitting"), 3)
        XCTAssertEqual(
            SumiScanning.suggestion(for: "defalut", in: ["default", "date"]),
            " Did you mean default?")
        XCTAssertEqual(SumiScanning.suggestion(for: "x", in: []), "")
    }

    func testEnvironmentDiagnosticsUseSharedComponentTable() {
        let environment = SumiLanguageSupport.environment(componentSources: [
            "components/Card.sumi": """
            @component Card(title) {
              <article>{title}</article>
            }
            """,
            "components/Broken.sumi": "@if broken {",
        ])

        let valid = SumiLanguageSupport.diagnostics(
            for: #"@Card(title: "Hi")"#,
            sourceName: "home.sumi",
            environment: environment
        )
        XCTAssertEqual(valid, [])

        let unknownArgument = SumiLanguageSupport.diagnostics(
            for: #"@Card(heading: "Hi")"#,
            sourceName: "home.sumi",
            environment: environment
        )
        XCTAssertEqual(unknownArgument.count, 1)
        XCTAssertTrue(unknownArgument.first?.message.contains("Unknown argument heading") == true)

        let broken = SumiLanguageSupport.diagnostics(
            for: "@if broken {",
            sourceName: "components/Broken.sumi",
            environment: environment
        )
        XCTAssertEqual(broken.count, 1)
        XCTAssertTrue(broken.first?.message.contains("Missing closing }") == true)
    }

}
