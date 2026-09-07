# Sacred Cards Codex Backlog

The repository contains:

- `MASTER_PROMPT.md` — feed this to Codex as the controlling instruction.
- `../stories/INDEX.md` — ordered story registry.
- `../stories/SC-xxx.md` — exactly one user story per file.
- `../docs/` — shared project documentation.

The master prompt enforces:

1. One story at a time.
2. Verification before completion.
3. Exactly one git commit per completed story.
4. No moving to the next story until the current story is DONE+committed or BLOCKED.
5. Dependency and priority-based task selection.

When the extracted card-data ZIP is added to the target repository, SC-101 is responsible for determining whether it should be reused directly, adapted, partially reused, or rejected.
