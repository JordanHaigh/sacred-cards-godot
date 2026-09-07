# Sacred Cards — Agent Guide

This repository is a Godot game project in its early setup phase. The owner is new to Godot, so agents must optimize for understandable progress, reversible changes, and working examples over clever architecture.

## Working agreement

- Start by inspecting the current files and the installed Godot version. Do not assume a Godot major version when a project file or executable can answer it.
- Preserve the user's intent and existing work. Make the smallest coherent change that moves the project forward.
- Explain Godot-specific terms the first time they matter: scene, node, resource, signal, autoload, and input action.
- Prefer typed GDScript, small scenes, explicit node ownership, and signals for communication between independent nodes.
- Keep gameplay logic separate from presentation where practical. Avoid introducing abstractions until there is a concrete second use.
- Never claim that a project was opened in the Godot editor or visually tested unless that actually happened.

## Repository conventions

Use Godot's `res://` paths and keep the project legible:

```text
scenes/       Reusable and level scenes
scripts/      GDScript attached to scenes or shared systems
resources/    Custom `.tres` data resources, when needed
art/          Images, sprites, fonts, and other visual assets
audio/        Sound effects and music
ui/           Reusable UI scenes and controls
addons/       Third-party or editor plugins, only when explicitly approved
```

Use `snake_case` for files and variables, `PascalCase` for classes and scene root types, and names that describe purpose rather than implementation details. Keep project settings, input actions, and autoloads minimal; explain each one in the change summary.

## Standard workflow

1. Inspect before editing. Read the relevant scene, script, project settings, and nearby conventions.
2. State a short implementation hypothesis and identify the smallest testable slice.
3. Make a focused change. Avoid unrelated formatting, asset replacement, or reorganizing the whole project.
4. Validate with the available Godot CLI/editor checks. If Godot is unavailable, say exactly what could not be verified.
5. Report changed files, checks run, known limitations, and one sensible next step for a beginner.

## Guardrails

- Do not delete, overwrite, or rename user files, scenes, assets, or settings unless the request clearly requires it.
- Do not add remote scripts, unreviewed addons, analytics, monetization, or external services without explicit approval.
- Do not download or invent copyrighted game assets as if they were licensed. Use placeholders or clearly identify what the user must supply.
- Do not hide errors with broad exception handling, silent fallbacks, or disabled warnings.
- Do not introduce an autoload/global singleton, custom editor plugin, dependency, or complex state machine unless the need is explained and the smaller alternative is insufficient.
- Do not change input mappings or project-wide settings without calling out the player-facing effect.
- Keep generated files and caches out of source control unless the project explicitly needs them.
- If a requested change could erase work, affect external services, or require a missing design decision, stop and ask before making that change.

## Completion standard

A change is complete when it is understandable to a first-time Godot user, uses the project's established structure, has a focused verification result, and leaves the project in a runnable or clearly diagnosable state. Use the personas in `.codex/personas/` to choose the right working posture; use the skills in `.codex/skills/` for repeatable Godot workflows.
