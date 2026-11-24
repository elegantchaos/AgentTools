# Preferences for the Local Claude Profile

AgentTools 4.3.1 opened the [persistent local profile](2026-11-20-claude-local-profile.md) but launched Claude with `--effort low`, disabled thinking, and fixed context and output limits. Claude Code 2.1.281 and 2.1.330 both read high effort and a 2,048-token output limit from a scratch profile when those overrides were removed. The loopback probe also confirmed that an endpoint in the profile can override the process environment, so the launcher pins the Ollama endpoint in its Claude settings as well.

The launcher now restores the saved model when it appears in the Ollama catalog and applies an explicit `--model` for one launch. Claude uses the profile's preference settings, and AgentTools supplies the local connection and empty tool configuration. A terminal smoke test compared the installed and draft builds with a scratch profile and a stub Claude executable. Formatting, lint, and all 327 targeted tests passed.
