# Global Agent Instructions

## Communication Protocol

**Default to Chinese for user-facing conversation; default to English for written artifacts.**

| Surface | Default Language | Override |
|---------|------------------|----------|
| Chat replies to the user | Chinese (Simplified) | User explicitly requests another language |
| Documentation, code comments, commit messages, file content | English (ASCII) | User explicitly requests another language, or existing artifact uses another language consistently |

**Rationale**: Conversations stay in the user's preferred working language for fluency, while written artifacts stay in English for cross-tool, cross-collaborator portability and consistency with the existing codebase.

## Data Analysis

### Numeric Statistics

**ALWAYS use the Python interpreter for numeric/statistical tasks.**

For any task involving numeric counts, statistics, aggregation, or calculation:

1. **MUST** use the Python interpreter to compute the result
2. **MUST NOT** rely on mental math, manual counting, or direct eyeballing
3. **MUST** report Python-computed results even when the answer seems obvious

**BLOCKING VIOLATION**: Manually computing or counting numeric/statistical results without using Python.

## Dependency Management

### Version Verification (MANDATORY)

**NEVER fabricate or guess dependency versions from memory.**

When adding dependencies to ANY project:

1. **MUST verify versions through**:
   - Official package registry search (npm, PyPI, crates.io, etc.)
   - Web search for official documentation
   - Package manager's native add commands (e.g., `npm install`, `pip install`, `cargo add`)
   - GitHub releases page for the official repository

2. **Default to latest stable version** unless:
   - Project constraints explicitly require older version
   - Known compatibility issues exist (verified, not assumed)
   - User explicitly requests specific version

3. **Evidence requirement**:
   - Before adding dependency, MUST show evidence of version (search result, registry output)
   - Document reasoning if not using latest

**BLOCKING VIOLATION**: Adding dependency with unverified version number.

## Code Style Preferences

### Comments Language

**ASCII-only comments by default.**

| Condition | Action |
|-----------|--------|
| User explicitly requests non-English | Use requested language |
| Existing codebase uses non-English consistently | Match existing style |
| No explicit preference | **ASCII-only** (English) |

Exception: If user or existing comments have chosen non-English, match that choice.

**CAUTION**: NEVER use — (em dash) or other non-ASCII punctuation in any files, including comments, documentation, and code, unless this is explicitly required.
In general, prefer simple ASCII punctuation (e.g., hyphen `-`) for clarity and compatibility.

## Documentation Editing

**Edit, don't rewrite.**

When modifying documentation files:

| Approach | When to Use |
|----------|-------------|
| **Targeted edits (PREFERRED)** | Modify only the specified content that needs to change |
| Delete + rewrite entire file | ONLY when reasoning determines it's absolutely necessary |

**Priority**: `edit` operations > `delete + add` operations

**Rationale**: Preserves existing structure, formatting, and unrelated content. Minimizes diff noise and accidental loss of information.

## Reviewing Delegated Code

> *(OhMyOpenCode/Oh-my-openagent) plugin-specific: applies to Task-based subagent delegation.)*

**Design-rationale comments in subagent output are red flags. Verify the rationale before accepting the code.**

Subagents are stateless: they see only the task handed at delegation time, not the plan evolution before or after. Comments like "in order to X" / "so that X" / "to ensure X" / "to keep X clean" encode the subagent's task-time understanding, which can drift after the main session revises the plan or invariants. The main session is the only place where plan-evolution context lives, so it is solely responsible for catching rationale drift.

**Trigger phrases to grep for in any subagent diff:**

- "in order to" / "so that" / "to ensure" / "to satisfy"
- "to keep ... clean" / "to avoid" / "to prevent"
- "for X invariant" / "for X to hold"

**Required check for every such comment:**

1. Is rationale X still a current requirement under the latest plan / invariant set?
2. If X has been revised or replaced, the code added "for X" is likely **dead code that may silently break an unrelated mechanism** (a short-circuit, a guard clause, a special-case branch).
3. Remove stale-rationale code immediately, even if it appears harmless.

**Failure cost is asymmetric:** catching stale rationale at review time is seconds (one grep). Catching it at expensive verification stages (experiment runs, integration tests, production) is hours and dollars.

**BLOCKING VIOLATION**: Merging subagent code containing a design-rationale comment without verifying the rationale against the current plan.

## Delegation Constraints

> *(OhMyOpenCode plugin-specific: requires Task delegation with category routing.)*

**`quick` and `unspecified-low` categories must NEVER be used for code modifications. Unless it's a one-line change that is trivial and low-risk, all code modifications must be delegated to a higher-capability category.**

Both categories run on Claude Sonnet (Sisyphus-Junior) and are restricted to read-only or analysis work.

- Search, grep, code reading, explanation, summarization
- Verification or sanity checks that do not edit files
- Q&A on existing code or documentation
- One-line changes that are trivial and low-risk (e.g., fixing a typo in a comment, adding a missing import, correcting a variable name in a single line)

Any task that **writes or modifies code** (edits, refactors, bugfixes, new code) must go to a higher-capability category matched to the domain: `deep`, `ultrabrain`, `unspecified-high`.

**Rationale**: Claude Sonnet's task-time reasoning is not rigorous enough for code modifications. It tends to add justification-driven side mechanisms (short-circuits, guard clauses, special-case branches) that survive past their original rationale and silently break unrelated systems. The cost of routing a code change through a stronger category is small; the cost of debugging a Claude Sonnet implementation oversight at experiment / integration time is large.

## OpenCode Skills

**Persist skill create/update changes in the dotfiles repo.**

When creating or updating OpenCode skills for this setup:

1. **MUST** write the skill files under `/home/qsdrqs/dotfiles/opencode/skills`
2. **MUST NOT** treat `~/.config/opencode/skills` as the source of truth

**Rationale**: `~/.config/opencode/skills` is activation output assembled from dotfiles and external symlinks, so direct edits there will drift from the managed source.

## Language-Specific Conventions

### Python

#### Multi-line String Composition (PREFERRED)

**Avoid consecutive `print()` or `list.append()` calls.**

```python
# PREFERRED: Multi-line f-string
output = f'''
Summary:
  Total: {total}
  Average: {avg}
  Status: {status}
'''
print(output)

# PREFERRED: Multi-line list with f-string
lines = f'''
Line 1: {value1}
Line 2: {value2}
Line 3: {value3}
'''.strip().split('\n')

# AVOID: Consecutive print calls
print(f"Summary:")
print(f"  Total: {total}")
print(f"  Average: {avg}")
print(f"  Status: {status}")

# AVOID: Consecutive append calls
lines.append(f"Line 1: {value1}")
lines.append(f"Line 2: {value2}")
lines.append(f"Line 3: {value3}")
```

**When to use f-strings over consecutive calls**:
- Structured text (reports, summaries, formatted output)
- Building string lists

**When consecutive calls are acceptable**:
- Conditional output (lines may be skipped based on logic)
- Single-line or two-line outputs

## Tool Use Instructions

**IMPORTANT**: You are ALWAYS encouraged to use search tools when available to verify information, find sources, and gather evidence. Do not rely solely on memory or assumptions for factual information.

### Search Tools

When using search tools, make sure to use all available search tools. E.g. You may have access to both `exa_web_search` and `brave_web_search`. Use both to get a comprehensive set of results. Do not rely on just one search tool if multiple are available.

#### Brave Search

Brave Search (`mcp_brave-search_brave_web_search`) returns clean results with direct URLs. Use it as the primary search tool for factual lookups and authoritative sources.

For specialized searches, also use:
- `brave_news_search` for recent news and current events
- `brave_image_search` for image lookups
- `brave_video_search` for video content

#### Exa Web Search

The Exa web search tool has rate limits. If you encounter rate limits, simply wait for 1 second by using `sleep 1` and then retry the search.
Always use all available search tools to gather information.
