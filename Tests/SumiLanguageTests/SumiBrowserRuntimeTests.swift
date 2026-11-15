import XCTest
import SumiLanguage

final class SumiBrowserRuntimeTests: XCTestCase {
    func testJavaScriptIsCompiledPlainJavaScript() {
        let js = SumiBrowserRuntime.javaScript
        XCTAssertFalse(js.isEmpty)
        XCTAssertTrue(js.contains("function bootSumiRuntime()"))
        XCTAssertTrue(js.contains("bootSumiRuntime();"))
        // Compiled output, not the raw Sumi client-script source.
        XCTAssertFalse(js.contains("@browserRuntime"))
        XCTAssertFalse(js.contains("func("))
        XCTAssertFalse(js.contains("func "))
        XCTAssertFalse(js.contains("=>"))
    }

    func testJavaScriptIsStableAcrossAccesses() {
        XCTAssertEqual(SumiBrowserRuntime.javaScript, SumiBrowserRuntime.javaScript)
    }

    func testJavaScriptReadsTheStateScriptTag() {
        let js = SumiBrowserRuntime.javaScript
        XCTAssertTrue(js.contains(#"script[data-sumi-state]"#))
        // A page with @navigation but no @state must still boot the runtime, so
        // the missing state hook cannot early-return out of bootSumiRuntime.
        XCTAssertFalse(js.contains("if (!stateScript) return;"))
    }

    func testJavaScriptImplementsTheNavigationProgressBar() {
        let js = SumiBrowserRuntime.javaScript
        // Public surface + injected, namespaced style with an app-overridable color.
        XCTAssertTrue(js.contains("Sumi.progress"))
        XCTAssertTrue(js.contains("sumi-progress-bar"))
        XCTAssertTrue(js.contains("--sumi-progress-color"))
        // @navigation options wired through the emitted config JSON.
        XCTAssertTrue(js.contains("progressBar"))
        XCTAssertTrue(js.contains("progressBarDelay"))
    }

    func testJavaScriptHandlesEveryAttributeTheRendererChecksFor() {
        // `SumiRenderResult.requiresRuntime` is driven by these attribute
        // names; the runtime must wire up each of them.
        let js = SumiBrowserRuntime.javaScript
        for attribute in [
            "data-sumi-text",
            "data-sumi-class",
            "data-sumi-class-",
            "data-sumi-bind-",
            "data-sumi-attr-",
            "data-sumi-style-",
            "data-sumi-style-template-",
            "data-sumi-on-",
        ] {
            XCTAssertTrue(js.contains(attribute), "Runtime does not handle \(attribute)")
        }
    }

    func testJavaScriptHandlesNavigationAndViewportContract() {
        let js = SumiBrowserRuntime.javaScript
        XCTAssertTrue(js.contains(#"script[data-sumi-navigation]"#))
        XCTAssertTrue(js.contains("sumi:navigate:"))
        XCTAssertTrue(js.contains("X-Sumi-Navigation"))
        XCTAssertTrue(js.contains("popstate"))
        XCTAssertTrue(js.contains("startViewTransition"))
        XCTAssertTrue(js.contains("data-sumi-on-visible"))
        XCTAssertTrue(js.contains("IntersectionObserver"))
        XCTAssertTrue(js.contains("getBoundingClientRect"))
    }

    func testRendererEmittedAttributesAreCoveredByTheRuntime() throws {
        let template = try SumiTemplate("""
        @state open = false
        @state label = "Hello"
        <button on:click="{open.toggle()}" aria-expanded="{open}" class:active="{open}" style:--x="{label}" hidden?="{!open}">{label}</button>
        <nav on:resize="{page.measure('.active', into: ['x'])}" style:--w="{label}px"></nav>
        """)

        let result = try template.renderResult([:])
        XCTAssertTrue(result.requiresRuntime)

        var names: Set<String> = []
        var searchRange = result.html.startIndex..<result.html.endIndex
        while let range = result.html.range(
            of: #"data-sumi-[A-Za-z0-9-]+"#, options: .regularExpression, range: searchRange)
        {
            names.insert(String(result.html[range]))
            searchRange = range.upperBound..<result.html.endIndex
        }
        XCTAssertFalse(names.isEmpty)
        XCTAssertTrue(names.contains("data-sumi-on-click"))
        XCTAssertTrue(names.contains("data-sumi-text"))

        let js = SumiBrowserRuntime.javaScript
        let exactNames: Set<String> = ["data-sumi-text", "data-sumi-class"]
        let prefixes = [
            "data-sumi-on-",
            "data-sumi-bind-",
            "data-sumi-attr-",
            "data-sumi-style-template-",
            "data-sumi-style-",
            "data-sumi-class-",
        ]
        for name in names {
            if exactNames.contains(name) {
                XCTAssertTrue(js.contains(name), "Runtime does not handle \(name)")
                continue
            }
            let prefix = prefixes.first { name.hasPrefix($0) }
            XCTAssertNotNil(prefix, "Renderer emitted \(name) which no runtime prefix covers")
            if let prefix {
                XCTAssertTrue(js.contains(prefix), "Runtime does not handle \(prefix)")
            }
        }
    }

    func testDriveRuntimeExposesPublicApiAndDriveContract() {
        // Behaviour is proven in the jsdom harness (SumiClientRuntimeTests); this
        // pins the public surface and keeps the no-arrow-function invariant.
        let js = SumiBrowserRuntime.javaScript
        XCTAssertTrue(js.contains("Sumi.apply"))
        XCTAssertTrue(js.contains("Sumi.visit"))
        XCTAssertTrue(js.contains("Sumi.morph"))
        XCTAssertTrue(js.contains("sumi-stream"))
        XCTAssertTrue(js.contains("sumi-frame"))
        XCTAssertTrue(js.contains("X-Sumi-Frame"))
        XCTAssertFalse(js.contains("=>"), "shipped runtime must avoid arrow functions")
    }

    func testJavaScriptImplementsStateActionsAndPageActions() {
        let js = SumiBrowserRuntime.javaScript
        // State actions: name.toggle() / set() / increment() / decrement().
        XCTAssertTrue(js.contains("toggle|set|increment|decrement"))
        // Page actions.
        for action in ["addClass", "removeClass", "toggleClass", "measure", "scrollToTop", "scrollTo"] {
            XCTAssertTrue(js.contains(action), "Runtime does not implement page.\(action)")
        }
    }
}
