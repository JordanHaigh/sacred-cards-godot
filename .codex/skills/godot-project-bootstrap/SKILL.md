---
name: godot-project-bootstrap
description: Create or extend a small Godot project scaffold, including project settings, a main scene, folders, and a first runnable slice. Use for new Godot projects or foundational setup, not for ordinary feature work.
---

# Godot project bootstrap

Set up the smallest runnable Godot project that supports the user's immediate goal and is easy for a beginner to inspect.

## Workflow

1. Inspect the repository and determine whether `project.godot` already exists.
2. Determine the available Godot version from the project or installed CLI/editor. Keep all syntax and settings compatible with that major version.
3. Create only the folders and files needed for the first slice. A minimal project usually needs `project.godot`, one main scene, and one or two scripts.
4. Make the main scene obvious in project settings and ensure every referenced resource path exists.
5. Prefer visible placeholder UI or shapes over downloaded art. Label placeholders so they can be replaced later.
6. Validate by parsing/loading the project with the available Godot command. If the editor or CLI is unavailable, report that limitation rather than guessing.

## Design constraints

- Do not add plugins, addons, autoloads, networking, persistence, or asset pipelines to an empty project unless the user asks for them.
- Use a simple scene tree and explain the purpose of each root node.
- Keep starter scripts short, typed where practical, and free of speculative systems.
- Do not silently choose a genre, control scheme, art style, or target platform. If a choice is necessary for a runnable example, choose a reversible placeholder and name the assumption.
- Preserve an existing project structure when extending one; this skill is not permission to reorganize it.

## Handoff

Tell the user how to open/run the project, what the starter scene demonstrates, which assumptions were made, and the next smallest decision they can make.

