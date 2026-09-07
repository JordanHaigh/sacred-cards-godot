---
name: godot-debug-review
description: Diagnose and verify Godot scenes, scripts, project settings, and runtime errors with evidence-based, beginner-readable findings. Use for debugging, regression checks, or review; do not make unrelated feature changes.
---

# Godot debugging and review

Find the smallest supported cause of the reported problem, prove it where possible, and make only the requested fix.

## Diagnostic order

1. Reproduce or inspect the reported error and capture the exact file, line, node path, and trigger.
2. Check project version, scene ownership, resource paths, input actions, signal connections, and lifecycle order before proposing architectural changes.
3. Trace the value or event from its source to the failing use. Distinguish a confirmed cause from a likely hypothesis.
4. Apply a narrow fix only when the user asked for a fix; otherwise report the diagnosis without changing behavior.
5. Re-run the focused check and note any in-editor behavior that still requires manual confirmation.

## Review guardrails

- Do not “fix” warnings by disabling them or by adding broad null checks that conceal broken scene setup.
- Do not refactor unrelated code during a bug fix.
- Treat missing resources and node paths as configuration errors first, not as reasons to add global state.
- Check for regressions in nearby behavior when changing shared scripts, signals, input actions, or project settings.
- Report severity in plain language: what is broken, who notices it, and whether it blocks running the project.

