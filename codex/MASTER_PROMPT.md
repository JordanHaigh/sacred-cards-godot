# CODEX MASTER PROMPT — SACRED CARDS GODOT PROJECT

You are the implementation agent for this Godot 4.x project.

Your job is to execute the project's user stories ONE AT A TIME.

The repository contains a backlog of individual story files under:

    stories/

Each story is a separate Markdown file and represents exactly one unit of implementation work.

You MUST NOT combine multiple stories into a single implementation pass.

---

## EXECUTION LOOP

Follow this loop exactly:

1. Inspect the repository.
2. Read `stories/INDEX.md`.
3. Identify the highest-priority story whose:
   - status is `READY` or `TODO`,
   - dependencies are all `DONE`,
   - and no blocking condition prevents execution.
4. Select EXACTLY ONE story.
5. Mark only that story `IN PROGRESS`.
6. Implement only that story.
7. Run all verification required by that story.
8. Fix any failures caused by your changes.
9. Re-run verification until the story satisfies its acceptance criteria.
10. Update the story file with:
    - Status
    - Files Created
    - Files Modified
    - Tests Added
    - Tests Run
    - Verification Result
    - Assumptions
    - Remaining Issues
11. If and only if the story is complete and verified:
    - mark it `DONE`
    - update `stories/INDEX.md`
    - create exactly ONE git commit for that story
12. End the current iteration.
13. Begin a new iteration and select the next eligible story.

Never work on two stories concurrently.

Never partially implement the next story while finishing the current one.

Never include unrelated refactors or cleanup in the current story unless they are strictly required to satisfy that story's acceptance criteria.

---

## GIT COMMIT RULES

Every completed user story gets exactly one implementation commit.

Required commit format:

    <TICKET-ID>: <short imperative summary>

Examples:

    SC-001: Initialize Godot project architecture
    SC-304: Implement battle resolver
    SC-603: Build deck builder UI

Before committing:

- confirm only changes relevant to the current story are included
- run `git status`
- review the diff
- run the story's required verification
- do not commit failing work

If the repository contains unrelated pre-existing uncommitted changes:

- do not discard them
- do not include them in the story commit
- stage only files belonging to the active story

If a clean story-specific commit cannot safely be created because unrelated edits overlap the same files:

- document the problem
- mark the story `BLOCKED`
- do not create a mixed commit
- move to another eligible story

Do not squash multiple stories into one commit.

Do not amend a previous story commit to add a later story.

---

## STORY SELECTION RULES

Priority order:

    P0
    P1
    P2
    P3

Within the same priority, choose the lowest numerical ticket ID whose dependencies are satisfied.

A `READY` story takes precedence over a `TODO` story of the same priority.

Never execute a `BLOCKED` story.

Never redo a `DONE` story unless a later ticket explicitly requires modifying its implementation.

If a regression is discovered in previously completed work while implementing the current story:

- fix it only if required to complete the current story
- document the regression and fix in the current story
- include the fix in the current story's commit

---

## DEFINITION OF DONE

A story is DONE only when ALL of the following are true:

- implementation exists
- acceptance criteria are satisfied
- project still launches where applicable
- required tests pass
- no new obvious runtime errors exist
- required documentation is updated
- the story's verification section is completed
- a story-specific git commit has been created

A story may not be marked DONE before its commit succeeds.

If implementation is complete but commit creation fails, leave the story `IN PROGRESS` or mark it `BLOCKED` with the reason.

---

## BLOCKERS

If essential information is missing:

1. do not guess if guessing would materially affect correctness
2. document the blocker inside the active story
3. mark it `BLOCKED`
4. update `stories/INDEX.md`
5. do not create a completion commit
6. move to another eligible story

Do not stop the entire backlog because one story is blocked.

---

## PROJECT ENGINEERING RULES

Use Godot 4.x.

Use typed GDScript.

Separate:

- data
- gameplay logic
- presentation/UI

Prefer data-driven systems.

Avoid giant manager classes.

Avoid giant `match` statements for individual cards.

Do not place authoritative gameplay rules inside UI scripts.

Do not mutate immutable card definitions during duels.

Use IDs for relationships between definitions.

Prefer deterministic gameplay logic.

Core duel systems should be testable without UI rendering where practical.

Inspect existing architecture before adding new architecture.

Do not replace working systems unnecessarily.

---

## SACRED CARDS RULE

This project recreates the gameplay model of Yu-Gi-Oh! The Sacred Cards.

Do NOT silently substitute modern Yu-Gi-Oh TCG rules.

When exact Sacred Cards behaviour is uncertain:

1. inspect existing repository data
2. inspect project documentation
3. inspect existing tests
4. isolate uncertain behaviour behind configuration
5. document the assumption in `docs/RULE_ASSUMPTIONS.md`

The supplied repository data is preferred over invented placeholder data where practical.

---

## USER-SUPPLIED CARD DATA

The owner may provide extracted JSON files containing Sacred Cards card data.

When such data is present:

- inspect it before creating a replacement schema
- treat it as potentially authoritative
- preserve original files
- do not destructively rewrite the source dump
- create adapters/importers when field names differ
- report malformed, incomplete, duplicated, or unclear records

Whether the supplied JSON should become the canonical runtime source is determined by story `SC-101`.

Do not assume the JSON is suitable until it has been inspected.

---

## REQUIRED PROJECT FILES

Maintain:

    stories/INDEX.md
    docs/IMPLEMENTATION_NOTES.md
    docs/RULE_ASSUMPTIONS.md
    docs/DATA_SCHEMA.md

Each story file is authoritative for its own scope.

Do not replace the individual-story workflow with one giant backlog implementation.

---

## ITERATION OUTPUT

At the end of EACH iteration, output only a concise summary of the one story just processed:

    Ticket:
    Final Status:
    Commit:
    Verification:
    Key Files:
    Blockers/Notes:

Then immediately begin the next iteration if another eligible story exists.

If no eligible stories remain, stop and report:

- DONE count
- BLOCKED count
- remaining TODO/READY count
- blockers preventing further work
