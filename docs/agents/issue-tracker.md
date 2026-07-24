# Issue Tracker: GitHub

Issues and planning artifacts for this repository live as GitHub issues. Use
the `gh` CLI for all operations.

## Conventions

- **Create an issue:** `gh issue create --title "..." --body "..."`. Use a
  heredoc for multi-line bodies.
- **Read an issue:** `gh issue view <number> --comments`, including labels.
- **List issues:** use `gh issue list` with appropriate state and label filters
  and request JSON when machine-readable output is needed.
- **Comment on an issue:** `gh issue comment <number> --body "..."`.
- **Apply or remove labels:** use `gh issue edit <number> --add-label "..."` or
  `--remove-label "..."`.
- **Close an issue:** `gh issue close <number> --comment "..."`.

Infer the repository from `git remote -v`; `gh` does this automatically inside
the checkout.

## Pull Requests As A Triage Surface

External pull requests are not a request surface. GitHub Issues hold planning
and incoming work. Implementation may happen on a work branch and be merged
directly into `main` without opening a pull request because this is a solo-dev
repository.

GitHub shares one number space across issues and pull requests. If a bare issue
number is ambiguous, try `gh pr view <number>` and then `gh issue view <number>`.

## Skill Operations

When a skill says to publish to the issue tracker, create a GitHub issue. When
a skill says to fetch a ticket, use `gh issue view <number> --comments`.

## Wayfinding Operations

Wayfinder represents a map as one issue labelled `wayfinder:map`, with its
tickets linked as GitHub sub-issues.

- **Map:** create an issue with `gh issue create --label wayfinder:map`.
- **Child ticket:** create an issue with one of `wayfinder:research`,
  `wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`, then link it
  through GitHub's sub-issues API. If sub-issues are unavailable, add it to a
  task list in the map and put `Part of #<map>` at the top of the ticket body.
- **Blocking:** use GitHub's native issue dependencies. Add an edge with
  `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-database-id>`.
  The database id comes from
  `gh api repos/<owner>/<repo>/issues/<number> --jq .id`. If native dependencies
  are unavailable, use a `Blocked by: #<number>` line in the ticket body.
- **Frontier:** inspect the map's open child issues in tracker order and exclude
  issues with open blockers or assignees. The first remaining issue is next.
- **Claim:** assign the ticket before work with
  `gh issue edit <number> --add-assignee @me`.
- **Resolve:** post the answer as a comment, close the ticket, and append a
  linked one-line context pointer to the map's Decisions-so-far section.
