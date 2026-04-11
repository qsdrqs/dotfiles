# Global Agent Instructions

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
