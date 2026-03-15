# Objective Translation Patterns

Reference guide for translating qualitative improvement objectives into measurable eval assertions. The objective-translator agent reads this during Phase 3.

## Pattern Catalog

### "More concise" / "Less verbose" / "Shorter outputs"

**Prompt strategy**: Use prompts that tend to produce verbose output — simple questions, tasks with straightforward answers, requests where the skill over-explains.

**Assertion templates**:
- "Output is under N words" (pick N based on task complexity — 100 for simple, 300 for moderate, 500 for complex)
- "Output is under N lines" (alternative line-based measure)
- "No repeated information or redundant explanations"
- "Key answer or action appears in the first paragraph"
- "Does not include unnecessary caveats or disclaimers"
- "Does not restate the user's request before answering"
- "Uses bullet points or lists instead of prose paragraphs where appropriate"

### "Handle edge cases" / "More robust" / "Don't break on weird input"

**Prompt strategy**: Generate prompts that exercise specific edge cases — empty input, unusually large input, malformed format, unicode/special characters, missing files, conflicting instructions.

**Assertion templates**:
- "Produces valid output even when [specific edge case]"
- "Does not crash, error, or produce empty output"
- "Gracefully reports the issue when input is invalid"
- "Does not silently ignore the problem"
- "Handles [unicode/special chars/empty string/null] without breaking"
- "Falls back to reasonable default behavior when [condition]"

**Prompt examples by edge case type**:
- Empty/missing input: Prompt references a file that doesn't exist, or provides no context
- Large input: Prompt with very long code blocks or many files
- Malformed: Prompt with typos, mixed formats, contradictory instructions
- Special chars: Prompt with unicode, emoji, code with special characters in identifiers

### "Better formatting" / "More structured output" / "Easier to read"

**Prompt strategy**: Use prompts requiring structured output — explanations, comparisons, multi-step instructions, code with documentation.

**Assertion templates**:
- "Uses markdown headers (## or ###) to organize sections"
- "Code blocks include language specifiers (```python, ```bash, etc.)"
- "Uses bullet points or numbered lists for sequential steps"
- "Tables use proper markdown syntax when comparing items"
- "Separates code from explanation clearly"
- "Does not produce walls of unbroken text"
- "Output has consistent heading hierarchy"

### "More accurate" / "Correct output" / "Fewer mistakes"

**Prompt strategy**: Use prompts with verifiable factual content — specific APIs, language features, file formats, algorithms.

**Assertion templates**:
- "Output contains [specific correct fact/syntax/pattern]"
- "Does not contain [specific common mistake or hallucination]"
- "Code examples are syntactically valid"
- "API calls use correct method signatures"
- "File paths and imports are valid"
- "Follows the documented behavior of [tool/library/framework]"

### "Better tool usage" / "Uses the right tools" / "More efficient tool calls"

**Prompt strategy**: Use prompts that require specific tool usage — file editing, searching, reading before writing, using Edit vs Write.

**Assertion templates**:
- "Uses [correct tool] instead of [wrong tool] for [operation]"
- "Reads the file before attempting to modify it"
- "Uses Edit tool for modifying existing files, not Write"
- "Uses Grep/Glob for searching, not Bash with grep/find"
- "Does not make redundant tool calls"
- "Reads error output and adjusts approach on failure"

### "Faster" / "More efficient" / "Fewer steps"

**Prompt strategy**: Normal prompts — the assertions measure the process rather than just the output.

**Assertion templates**:
- "Completes the task in under N tool calls"
- "Does not read files that aren't relevant to the task"
- "Does not perform redundant searches"
- "Parallelizes independent operations where possible"
- "Does not repeat failed approaches without changing strategy"

### "Better error handling" / "Don't fail silently" / "Recover from errors"

**Prompt strategy**: Use prompts that will trigger errors — wrong file paths, failing commands, permission issues, malformed data.

**Assertion templates**:
- "Reports the error clearly to the user with actionable information"
- "Does not silently fail or produce empty output"
- "Attempts an alternative approach when the first approach fails"
- "Does not retry the exact same failed operation"
- "Explains what went wrong and suggests next steps"
- "Preserves existing work/state when encountering errors"

### "Follow instructions better" / "Do what I asked" / "Stay on task"

**Prompt strategy**: Use prompts with specific, detailed instructions — the assertions check that each instruction was followed.

**Assertion templates**:
- "Output includes [specific requested element]"
- "Does not include [explicitly excluded element]"
- "Follows the specified format/structure"
- "Addresses all N points from the user's request"
- "Does not add unrequested features or modifications"
- "Stays within the specified scope"

## Assertion Quality Rules

### Must-have properties

1. **Verifiable**: A grader can determine pass/fail by reading the output or execution transcript. No subjective judgment required.
2. **Discriminating**: The assertion would FAIL if the skill didn't do the right thing. Avoid trivially-passing assertions.
3. **Specific**: Two different graders would agree on the pass/fail result.
4. **Connected**: Each assertion clearly maps to a qualitative objective the user cares about.

### Anti-patterns (DO NOT use these)

- "Output is high quality" — subjective, unverifiable
- "Output exists" — trivially passes, non-discriminating
- "The skill works correctly" — too vague
- "Output is well-written" — subjective
- "Completes in reasonable time" — unmeasurable from output
- "User would be satisfied" — subjective

### Good patterns

- Mix positive ("includes X") and negative ("does NOT include Y") assertions
- Include at least one structural assertion (format, length, organization)
- Include at least one content assertion (specific information present/absent)
- Make prompts realistic — include context, backstory, specific details, casual language
- Each eval should have 3-5 assertions (fewer = too easy to pass, more = too noisy)

## Prompt Crafting Guidelines

Realistic eval prompts share these characteristics:
- **Specific context**: "I'm working on a React app that uses TypeScript and Zustand for state management" not "I have a web app"
- **Casual language**: "Can you help me fix..." or "I need to..." not formal spec language
- **Real details**: Specific file names, function names, error messages when relevant
- **Implicit requirements**: Some things the user expects but doesn't state (like not breaking other code)
- **Varying complexity**: Mix simple tasks, moderate tasks, and complex tasks across evals

## Combining Objectives

When multiple objectives apply to the same eval:
- A single prompt can have assertions from multiple objectives
- Keep assertions from different objectives distinguishable (a grader should know which objective each measures)
- Don't overload a single eval with too many objectives — spread them across prompts
- Prioritize: if objectives conflict (conciseness vs thoroughness), the user's primary objective wins

## Test Category Balance

When generating evals, distribute prompts across these categories:

| Category | Count | Purpose |
|---|---|---|
| Happy Path | 3-5 | Typical tasks the skill should handle well |
| Edge Cases | 2-3 | Ambiguous input, missing context, boundary conditions |
| Error Scenarios | 1-2 | Requests outside skill domain, broken input |
| Anti-Pattern Checks | 1-2 | Known bad behaviors the skill should avoid |

A good eval suite of 7-10 evals has representation from all four categories.
Don't cluster all evals around one type — a skill that aces happy paths but
fails every edge case is not a good skill.
