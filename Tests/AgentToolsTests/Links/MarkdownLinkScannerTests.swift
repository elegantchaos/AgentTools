// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Checks which Markdown constructs count as links, and how their destinations are read.
struct MarkdownLinkScannerTests {
  /// Inline links, images, bracketed destinations, titles and reference definitions are all found, with their lines.
  @Test func findsEveryLinkForm() {
    let text = """
      See [one](a.md) and ![image](b.png "Title").
      A [spaced](<c d.md>) link, and [parens](e_(f).md).

      [label]: ../g.md
      [^1]: A footnote, which is not a link.
      """
    let links = MarkdownLinkScanner.links(in: text)
    #expect(links.map(\.destination) == ["a.md", "b.png", "c d.md", "e_(f).md", "../g.md"])
    #expect(links.map(\.line) == [1, 1, 2, 2, 4])
  }

  /// Links shown as examples in code are not navigation, so they are skipped.
  @Test func ignoresLinksInCode() {
    let text = """
      [before](before.md)
      ```markdown
      [fenced](fenced.md)
      ~~~
      ```
      Use `[span](span.md)` for links, and ``a ` [nested](nested.md)``.
      ~~~~
      [tilde](tilde.md)
      ~~~~
      [after](after.md)
      """
    #expect(MarkdownLinkScanner.links(in: text).map(\.destination) == ["before.md", "after.md"])
  }

  /// The recorded range covers exactly the destination, so it can be replaced without touching text or title.
  @Test func rangeCoversTheDestination() throws {
    let text = "A [link](<old path.md> \"Title\") here."
    let link = try #require(MarkdownLinkScanner.links(in: text).first)
    #expect(text.replacingCharacters(in: link.range, with: "new.md") == "A [link](new.md \"Title\") here.")
  }

  /// Only destinations that name a file are checked; the path is decoded and loses its anchor and query.
  @Test(arguments: [
    ("https://example.com/a.md", nil), ("mailto:sam@example.com", nil), ("#section", nil), ("//example.com/a.md", nil),
    ("a%20b.md#section", "a b.md"), ("../Entr%C3%A9e.md", "../Entrée.md"), ("Entrée.md?raw=1", "Entrée.md"), ("/Docs/a.md", "/Docs/a.md"),
  ])
  func pathIsTheDecodedFilePart(destination: String, expected: String?) throws {
    let link = try #require(MarkdownLinkScanner.links(in: "[x](\(destination))").first)
    #expect(link.path == expected)
  }

  /// Paths resolve against the linking file's folder, a leading slash means the root, and leaving the root fails.
  @Test(arguments: [
    ("b.md", "Docs/b.md"), ("../b.md", "b.md"), ("./Sub/../b.md", "Docs/b.md"), ("/Other/b.md", "Other/b.md"), ("../../b.md", nil), ("..", ""),
  ])
  func repositoryPathResolvesFromTheLinkingFile(destination: String, expected: String?) throws {
    let link = try #require(MarkdownLinkScanner.links(in: "[x](\(destination))").first)
    #expect(link.repositoryPath(from: "Docs/a.md") == expected)
  }
}
