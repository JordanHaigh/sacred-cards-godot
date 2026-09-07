---
name: godot-feature-work
description: Implement a focused Godot gameplay, interaction, or UI feature in an existing project while keeping scenes and scripts understandable. Use for feature requests after the project has a runnable foundation.
---

# Godot feature work

Implement one user-visible slice at a time, with a clear path from input to state change to presentation.

## Before editing

- Read `AGENTS.md`, the target scene, attached scripts, relevant resources, and input actions.
- Identify the owning scene/node for the behavior and avoid reaching into unrelated nodes through fragile absolute paths.
- Check whether the behavior already exists before adding a second implementation.

## Implementation guidance

- Prefer signals for decoupled events, exported variables for small configuration, and resources for data that should be edited independently of code.
- Keep UI logic in UI scenes and game rules in gameplay scripts; connect them through a small, explicit interface.
- Add input actions only when the feature needs them, and use descriptive action names.
- Use placeholder visuals and deterministic sample data when art, balancing, or content is not yet specified.
- Make failure states visible and debuggable. Avoid silently ignoring missing nodes or resources.
- Keep each change small enough that a beginner can compare it with the scene tree and understand what changed.

## Verification

Verify at least one meaningful invariant: the project parses, the scene loads, the input action is present, the signal fires, or the state changes as requested. Run a headless check when possible, then describe what still needs an in-editor playtest.

Do not broaden a feature request into a redesign, save system, plugin, or content production task without explicit approval.

