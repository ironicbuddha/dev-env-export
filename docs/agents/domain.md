# Domain Docs

This is a single-context repository. Engineering skills should consume its
domain documentation as follows.

## Before Exploring

- Read root `CONTEXT.md` for the project's canonical language.
- Read relevant decisions under `docs/adr/` before changing an affected area.
- If either location is absent, proceed silently. Domain-modeling workflows
  create files lazily when a real term or decision needs to be recorded.

## Use The Glossary's Vocabulary

Use terms defined in `CONTEXT.md` in issue titles, plans, tests, and code. Avoid
synonyms that the glossary explicitly rejects. If a needed concept is missing,
either reconsider the new language or note the gap for domain modeling.

## Flag ADR Conflicts

If proposed work contradicts an existing ADR, surface the conflict explicitly
instead of silently overriding the earlier decision.
