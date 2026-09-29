// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Tests adding writable roots to Codex's TOML configuration while leaving the rest of the text alone.
struct CodexSandboxConfigTests {
  /// Paths added in every test.
  let paths = ["/cache/swiftpm", "/cache/clang"]

  /// Creates the table and key in an empty configuration.
  @Test func addsTableToEmptyConfig() throws {
    let updated = try CodexSandboxConfig.adding(paths, to: "")
    #expect(updated == "[sandbox_workspace_write]\nwritable_roots = [\"/cache/swiftpm\", \"/cache/clang\"]\n")
  }

  /// Appends the table after existing settings, separated by a blank line.
  @Test func appendsTableAfterExistingSettings() throws {
    let updated = try CodexSandboxConfig.adding(paths, to: "model = \"gpt\"\n")
    #expect(updated == "model = \"gpt\"\n\n[sandbox_workspace_write]\nwritable_roots = [\"/cache/swiftpm\", \"/cache/clang\"]\n")
  }

  /// Adds the key directly after an existing table header that lacks it.
  @Test func addsKeyToExistingTable() throws {
    let text = "[sandbox_workspace_write] # comment\nnetwork_access = true\n\n[other]\nx = 1\n"
    let updated = try CodexSandboxConfig.adding(paths, to: text)
    #expect(updated == "[sandbox_workspace_write] # comment\nwritable_roots = [\"/cache/swiftpm\", \"/cache/clang\"]\nnetwork_access = true\n\n[other]\nx = 1\n")
  }

  /// Stops looking for the key at an array-of-tables header, rather than reading the next entry's keys.
  @Test func stopsAtArrayOfTables() throws {
    let text = "[sandbox_workspace_write]\nnetwork_access = true\n\n[[hooks]]\nwritable_roots = [\"/other\"]\n"
    let updated = try CodexSandboxConfig.adding(paths, to: text)
    #expect(updated == "[sandbox_workspace_write]\nwritable_roots = [\"/cache/swiftpm\", \"/cache/clang\"]\nnetwork_access = true\n\n[[hooks]]\nwritable_roots = [\"/other\"]\n")
  }

  /// Appends missing entries to a single-line array.
  @Test func extendsSingleLineArray() throws {
    let text = "[sandbox_workspace_write]\nwritable_roots = [\"/cache/swiftpm\"]  # keep\n"
    let updated = try CodexSandboxConfig.adding(paths, to: text)
    #expect(updated == "[sandbox_workspace_write]\nwritable_roots = [\"/cache/swiftpm\", \"/cache/clang\"]  # keep\n")
  }

  /// Fills an empty single-line array.
  @Test func fillsEmptyArray() throws {
    let text = "[sandbox_workspace_write]\nwritable_roots = []\n"
    let updated = try CodexSandboxConfig.adding(paths, to: text)
    #expect(updated == "[sandbox_workspace_write]\nwritable_roots = [\"/cache/swiftpm\", \"/cache/clang\"]\n")
  }

  /// Appends entries to a multi-line array with a trailing comma, keeping its comments and indentation.
  @Test func extendsMultiLineArrayWithTrailingComma() throws {
    let text = """
      [sandbox_workspace_write]
      writable_roots = [
          # the package cache
          "/other",
          '/literal',
      ]
      network_access = true

      """
    let updated = try CodexSandboxConfig.adding(paths, to: text)
    #expect(
      updated == """
        [sandbox_workspace_write]
        writable_roots = [
            # the package cache
            "/other",
            '/literal',
            "/cache/swiftpm",
            "/cache/clang",
        ]
        network_access = true

        """
    )
  }

  /// Adds the missing comma after the last entry of a multi-line array without one.
  @Test func extendsMultiLineArrayWithoutTrailingComma() throws {
    let text = "[sandbox_workspace_write]\nwritable_roots = [\n  \"/other\" # note\n]\n"
    let updated = try CodexSandboxConfig.adding(paths, to: text)
    #expect(updated == "[sandbox_workspace_write]\nwritable_roots = [\n  \"/other\", # note\n  \"/cache/swiftpm\",\n  \"/cache/clang\",\n]\n")
  }

  /// Adds only the entries that are missing, comparing decoded string values.
  @Test func addsOnlyMissingEntries() throws {
    let text = "[sandbox_workspace_write]\nwritable_roots = ['/cache/swiftpm', \"/cache/\\u0063lang\"]\n"
    #expect(try CodexSandboxConfig.adding(paths, to: text) == nil)
  }

  /// Ignores a key with the same name in another table.
  @Test func ignoresKeyInOtherTable() throws {
    let text = "[other]\nwritable_roots = [\"/cache/swiftpm\"]\n"
    let updated = try CodexSandboxConfig.adding(paths, to: text)
    #expect(updated == "[other]\nwritable_roots = [\"/cache/swiftpm\"]\n\n[sandbox_workspace_write]\nwritable_roots = [\"/cache/swiftpm\", \"/cache/clang\"]\n")
  }

  /// Escapes quotes and backslashes in added paths.
  @Test func escapesAddedPaths() throws {
    let updated = try CodexSandboxConfig.adding(["/a \"b\"\\c"], to: "")
    #expect(updated == "[sandbox_workspace_write]\nwritable_roots = [\"/a \\\"b\\\"\\\\c\"]\n")
  }

  /// Extends an array set with a dotted key in the root table.
  @Test func extendsDottedKey() throws {
    let text = "model = \"gpt\"\nsandbox_workspace_write.writable_roots = [\"/cache/swiftpm\"]\n\n[other]\nx = 1\n"
    let updated = try CodexSandboxConfig.adding(paths, to: text)
    #expect(updated == "model = \"gpt\"\nsandbox_workspace_write.writable_roots = [\"/cache/swiftpm\", \"/cache/clang\"]\n\n[other]\nx = 1\n")
  }

  /// Adds a dotted key after other dotted keys for the table, since a table header would then be invalid.
  @Test func addsDottedKeyAfterOtherDottedKeys() throws {
    let text = "sandbox_workspace_write.network_access = true\nmodel = \"gpt\"\n"
    let updated = try CodexSandboxConfig.adding(paths, to: text)
    #expect(updated == "sandbox_workspace_write.network_access = true\nsandbox_workspace_write.writable_roots = [\"/cache/swiftpm\", \"/cache/clang\"]\nmodel = \"gpt\"\n")
  }

  /// Refuses layouts it cannot edit safely, rather than guessing.
  @Test(arguments: [
    "sandbox_workspace_write = { writable_roots = [\"/x\"] }\n",
    "[sandbox_workspace_write]\nwritable_roots = \"/x\"\n",
    "[sandbox_workspace_write]\nwritable_roots = [\"/x\"\n",
    "[sandbox_workspace_write]\nwritable_roots = [\"\"\"/x\"\"\"]\n",
  ])
  func refusesUnsupportedLayouts(text: String) {
    #expect(throws: ToolError.self) {
      try CodexSandboxConfig.adding(paths, to: text)
    }
  }
}
