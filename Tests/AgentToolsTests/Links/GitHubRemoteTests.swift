// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Checks that owner and repository come from the remote URL forms Git uses, and how permalinks are built.
struct GitHubRemoteTests {
  /// SSH and HTTPS remotes, with or without `.git`, name the same repository.
  @Test(arguments: [
    "git@github.com:example/project.git", "git@github.com:example/project", "ssh://git@github.com/example/project.git",
    "https://github.com/example/project.git", "https://github.com/example/project/", "https://user@github.com/example/project\n",
  ])
  func parsesRemoteURLs(url: String) throws {
    let remote = try GitHubRemote(url: url)
    #expect(remote.owner == "example")
    #expect(remote.name == "project")
  }

  /// A remote on another host cannot produce GitHub permalinks, so it is refused with the URL named.
  @Test func rejectsOtherHosts() {
    #expect {
      try GitHubRemote(url: "git@gitlab.com:example/project.git")
    } throws: { error in
      (error as? ToolError)?.description.contains("gitlab.com") == true
    }
  }

  /// Files use `blob` and directories `tree`; the path is encoded so it cannot end a Markdown link early.
  @Test(arguments: [(false, "blob"), (true, "tree")])
  func permalinkEncodesThePath(isDirectory: Bool, kind: String) throws {
    let remote = try GitHubRemote(url: "git@github.com:example/project.git")
    let resolution = LinkResolution(commit: "abc123", path: "Docs/Entrée (old) #1.md", isDirectory: isDirectory, basis: .introduced)
    #expect(remote.permalink(to: resolution, fragment: "#part") == "https://github.com/example/project/\(kind)/abc123/Docs/Entr%C3%A9e%20%28old%29%20%231.md#part")
  }
}
