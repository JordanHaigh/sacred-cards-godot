# CODEX START HERE

Feed `codex/MASTER_PROMPT.md` to Codex as the controlling prompt.

This bundle contains the implementation backlog plus the source/reference data currently available for the project.

## Important paths

- `codex/MASTER_PROMPT.md` — controlling autonomous-agent instructions.
- `stories/INDEX.md` — Jira-style story index.
- `stories/SC-*.md` — one implementation story per file.
- `data/cards_json/` — extracted 900-card JSON dataset supplied by the project owner.
- `data/raw/original_card_json_dump.zip` — untouched original uploaded archive.
- `reference/Yu-Gi-Oh! The Sacred Cards - Card List - Game Boy Advance - By Griffin_Knight - GameFAQs.pdf` — user-supplied card-list reference.

## Card-data policy

The JSON dump is source data supplied by the project owner. Do not destructively rewrite it.

SC-101 must inspect the real dataset and document its schema before CardDefinition/CardDatabase implementation is finalized.

Current preliminary assessment: REUSE VIA ADAPTER is strongly recommended.

The GameFAQs PDF is reference material. Use it to enrich/verify Sacred Cards-specific metadata and identify mechanical card effects, but do not make the game runtime depend on parsing the PDF.

Normalize mechanical effects into reusable effect IDs plus parameters rather than one bespoke implementation per card whenever possible.

## Agent transaction rule

Exactly one story at a time:

SELECT ONE STORY
→ MARK IN PROGRESS
→ IMPLEMENT ONLY THAT STORY
→ VERIFY
→ FIX UNTIL PASSING
→ UPDATE STORY
→ COMMIT THAT STORY
→ ONLY THEN SELECT NEXT STORY

Do not combine stories into one commit.
