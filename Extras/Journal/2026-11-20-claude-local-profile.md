# Persistent Local Claude Profile

`agt claude` keeps its own profile at `~/Library/Application Support/AgentTools/ClaudeOllama`. The profile retains onboarding, workspace trust, and local session history after exit. The launcher still supplies the Ollama endpoint and placeholder credential for the child process. Sharing a profile with hosted Claude or Claude.app is deferred until its effects can be verified.

AgentTools 4.3.0 repeated onboarding in the same workspace after a normal exit. The follow-up build completed onboarding and workspace trust once, then opened the same workspace directly on its second launch. The smoke test used a scratch home, sent no inference request, and left the hosted settings checksums unchanged. Formatting, lint, and all 326 targeted tests passed.
