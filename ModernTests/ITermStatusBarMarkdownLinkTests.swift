//
//  ITermStatusBarMarkdownLinkTests.swift
//  ModernTests
//
//  Pins the `[display](url)` markdown parsing that backs clickable status-bar
//  links: markdown syntax is stripped from the rendered text, each link's
//  display span carries the URL (NSLinkAttributeName) and a dotted underline,
//  literal text carries neither, and a string with no links returns nil (so
//  callers keep their plain, collapsible stringValue path).
//

import XCTest
@testable import iTerm2SharedARC

final class ITermStatusBarMarkdownLinkTests: XCTestCase {
    private let color = NSColor.labelColor
    private let font = NSFont.systemFont(ofSize: 12)

    private func parse(_ string: String) -> NSAttributedString? {
        return iTermStatusBarTextComponent.attributedStringWithMarkdownLinks(from: string,
                                                                             color: color,
                                                                             font: font)
    }

    func testNoLinksReturnsNil() {
        XCTAssertNil(parse("plain text, no links"))
        XCTAssertNil(parse(""))
        // `](` must be adjacent — incidental brackets/parens are not a link.
        XCTAssertNil(parse("[3] (main)"))
    }

    func testSingleLinkStripsMarkdownAndCarriesURL() {
        let out = parse("a [b](https://example.com/x) c")
        XCTAssertEqual(out?.string, "a b c")
        // The link rides the display span ("b" at index 2), not the literal.
        XCTAssertEqual(out?.attribute(.link, at: 2, effectiveRange: nil) as? URL,
                       URL(string: "https://example.com/x"))
        XCTAssertNil(out?.attribute(.link, at: 0, effectiveRange: nil))
        // Dotted underline on the link, none on the literal text.
        XCTAssertNotNil(out?.attribute(.underlineStyle, at: 2, effectiveRange: nil))
        XCTAssertNil(out?.attribute(.underlineStyle, at: 0, effectiveRange: nil))
    }

    func testMultipleLinksWithLiteralSeparator() {
        let out = parse("[a](https://x/1), [b](https://x/2)")
        XCTAssertEqual(out?.string, "a, b")
        XCTAssertEqual(out?.attribute(.link, at: 0, effectiveRange: nil) as? URL, URL(string: "https://x/1"))
        XCTAssertNil(out?.attribute(.link, at: 1, effectiveRange: nil))  // the ", " separator
        XCTAssertEqual(out?.attribute(.link, at: 3, effectiveRange: nil) as? URL, URL(string: "https://x/2"))
    }

    func testLinkOnlyString() {
        let out = parse("[only](https://x/only)")
        XCTAssertEqual(out?.string, "only")
        XCTAssertEqual(out?.attribute(.link, at: 0, effectiveRange: nil) as? URL, URL(string: "https://x/only"))
    }
}
