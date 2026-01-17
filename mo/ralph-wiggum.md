Feature prompt (paste output of `/create-prompt` here):

<feature_prompt>
PASTE_FEATURE_PROMPT_HERE
</feature_prompt>

```bash
/ralph-loop "
PASTE_FEATURE_PROMPT_HERE

Feature: FEATURE_SLUG
Branch: git checkout FEATURE_SLUG

PHASE 1 - COMPLETION CHECK:
- Read specs/FEATURE_SLUG/tasks.md
- If any tasks unchecked (- [ ]), complete them first
- Mark completed tasks (- [x])

PHASE 2 - ROTATING PERSONA REVIEW (cycle each iteration):
ITERATION MOD 6:

[0] CODE REVIEWER:
- Review code for bugs, security issues, edge cases
- Check error handling and types
- Fix any issues found

[1] SYSTEM ARCHITECT:
- Review file structure and dependencies
- Check separation of concerns
- Refactor if needed

[2] FRONTEND DESIGNER:
- Use /frontend-design skill
- Review UI/UX for this feature
- Improve components, accessibility, responsiveness

[3] QA ENGINEER:
- Run npm test
- Check test coverage, aim for 90%+
- Write missing unit tests for edge cases
- Run npm run lint && npm run build

[4] PROJECT MANAGER:
- Verify all acceptance criteria met
- Check specs/FEATURE_SLUG/spec.md requirements
- Document any gaps

[5] BUSINESS ANALYST:
- Review feature from user perspective
- Check if flows make sense
- Identify UX friction points

EACH ITERATION:
- Identify current persona (iteration % 6)
- Perform that persona's review
- Make ONE improvement or fix
- Commit with message: '[persona] description'
- If no issues found by ANY persona for 2 full cycles, output completion

OUTPUT <promise>FEATURE_READY</promise> when all personas report
" --completion-promise "FEATURE_READY" --max-iterations 30

```
