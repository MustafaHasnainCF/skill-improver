# Skill Audit Checklist

Reference checklist for the experimenter agent. When analyzing failures, scan this checklist to identify root causes that the standard failure categories might miss.

## Description Quality

- [ ] Uses third-person "Use when..." format (not "This skill will...")
- [ ] Includes specific trigger phrases in quotes (e.g., "refactor", "add tests")
- [ ] Lists file types, task types, keywords, and contexts that should trigger the skill
- [ ] "Pushy" enough to combat undertriggering — describes symptoms users have, not just solutions
- [ ] Under 1024 characters total
- [ ] Symptom-based triggers ("Use when tests fail...") not solution-based ("Use to run test framework...")

## Body Structure

- [ ] Under 500 lines, imperative style throughout
- [ ] Clear purpose statement in first 1-2 sentences
- [ ] Core Workflow section with step-by-step procedures
- [ ] Quick Reference section (tables, checklists) for key rules
- [ ] Additional Resources section listing all bundled reference files
- [ ] Explicit output format definition for any structured outputs
- [ ] XML tags to separate instructions, context, and examples
- [ ] Self-verification step for critical outputs (e.g., "Before outputting, check that...")

## Progressive Disclosure

- [ ] Core procedures in SKILL.md, supporting details in references/
- [ ] No duplicated information across SKILL.md and reference files
- [ ] References go one level deep (no nested reference chains)
- [ ] Large reference files include a table of contents
- [ ] No `@` force-load links (let the agent pull references on demand)

## Anti-Patterns (these should NOT be present)

- [ ] No aggressive language ("CRITICAL!", "NEVER EVER", "EXTREMELY IMPORTANT")
- [ ] No second person ("You should...", "You must...") — use imperative instead
- [ ] No over-constraining role/behavior preambles
- [ ] Not bloated (>3,000 words in SKILL.md means content should move to references/)
- [ ] Output format is defined when the skill produces structured output

## Failure-Category-to-Fix Mapping

When the experimenter identifies a failure, use this table to generate more precise hypotheses:

| Category | Symptom | Typical Fix |
|---|---|---|
| Instruction Gap | Agent didn't know what to do | Add or strengthen a specific instruction in the relevant workflow step |
| Structural Issue | Agent couldn't find the instruction | Move the instruction to a more prominent location (earlier, under a clearer heading) |
| Ambiguity | Agent interpreted differently than intended | Make instruction more precise, add a concrete example |
| Missing Context | Agent needed info that wasn't provided | Add context to SKILL.md or create/update a reference file |
| Over-specification | Agent too rigid, couldn't adapt to variation | Soften language, explain the "why" instead of prescribing rigid rules |
| Triggering Failure | Skill didn't activate when it should have | Improve description frontmatter — add trigger phrases, symptom-based language |
