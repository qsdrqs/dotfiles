---
name: researcher
description: "Multi-agent parallel research workflow: YOU (the Orchestrator) spawn 6-12+ research agents simultaneously, each investigating ONE specific angle. YOU decompose the topic into 3-7 directions, launch parallel agents per direction, then synthesize all findings. DO NOT use a single agent - use multiple agents in parallel. Use for complex research requiring comprehensive coverage."
---

# Researcher (Multi-Agent Iterative Web Research)

## ⚠️ CRITICAL: READ THIS FIRST

**YOU ARE THE ORCHESTRATOR. DO NOT DELEGATE EVERYTHING TO A SINGLE AGENT.**

❌ **WRONG**: Launching 1 agent to "research everything"  
✅ **CORRECT**: Launching 6-12+ agents in parallel, each with a specific focus

Your job is to **COORDINATE** multiple agents, not to **DO** the research yourself and not to ask one agent to do everything.

---

## Architecture Overview

This skill uses a **multi-agent collaborative architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR (You)                       │
│         - Decomposes problem into 3-7 directions            │
│         - Spawns 6-12+ parallel research agents             │
│         - Monitors progress & collects results              │
│         - Synthesizes & validates findings                  │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┼───────────┬───────────────┐
         │           │           │               │
    ┌────▼───┐  ┌────▼───┐  ┌────▼───┐     ┌────▼────┐
    │Agent A1│  │Agent A2│  │Agent B1│     │Agent C1 │
    │(Docs)  │  │(Forums)│  │(Papers)│     │(Repos)  │
    └────┬───┘  └────┬───┘  └────┬───┘     └────┬────┘
         │           │           │               │
         └───────────┴───────────┴───────────────┘
                     │
              ┌──────▼──────┐
              │  SYNTHESIS  │
              │  & REPORT   │
              └─────────────┘
```

### Role Definitions

**🎭 Orchestrator（指挥者）- That's YOU:**
- **DECOMPOSE** the research into 3-7 distinct directions
- **SPAWN** 6-12+ specialized agents in **PARALLEL** (not sequentially)
- **COORDINATE**: Each agent gets ONE specific angle only
- **SYNTHESIZE**: Combine findings from all agents, cross-validate

**🤖 Research Agents（研究员）:**
- Each agent focuses on **ONE** specific subtopic/angle
- Agents run independently in parallel (`run_in_background=True`)
- Agents **DO NOT** spawn other agents - that's YOUR job
- Agents return structured findings for YOU to synthesize

### Key Numbers to Remember

| Metric | Target |
|--------|--------|
| Research directions | 3-7 |
| Agents per direction | 2-4 |
| **Total agents spawned** | **6-12+** |
| Sequential agents | 0 (all parallel) |

**If you're only spawning 1-2 agents, you're doing it wrong.**

**Research Agents（研究员）:**
- Each agent focuses on ONE specific subtopic/angle
- Agents run independently and in parallel (`run_in_background=True`)
- Agents fetch original sources (not just snippets)
- Agents return structured findings with evidence links

---

## 🚨 Orchestrator Responsibilities (READ CAREFULLY)

### What YOU Must Do (The Orchestrator)

When user asks for research, **YOU** must:

1. **DECOMPOSE** - Break the topic into 3-7 distinct research directions
   - Example: "GraphQL vs REST" → Directions: GraphQL Perf, REST Perf, Migration Cost, Learning Curve

2. **SPAWN MULTIPLE AGENTS** - Launch 6-12+ agents IN PARALLEL
   ```python
   # WRONG - Don't do this:
   task(description="Research everything", prompt="Research GraphQL vs REST...")
   
   # CORRECT - Do this:
   task_A1 = task(..., run_in_background=True)  # GraphQL docs
   task_A2 = task(..., run_in_background=True)  # GraphQL community
   task_B1 = task(..., run_in_background=True)  # REST docs
   task_B2 = task(..., run_in_background=True)  # REST community
   task_C1 = task(..., run_in_background=True)  # Comparison benchmarks
   # ... etc
   ```

3. **ASSIGN SPECIFIC ANGLES** - Each agent gets ONE narrow focus:
   - Agent 1: GraphQL official docs & benchmarks
   - Agent 2: GraphQL community issues & Reddit discussions
   - Agent 3: REST official docs & specs
   - Agent 4: REST production experience reports
   - Agent 5: Comparative benchmark studies
   - Agent 6: Migration case studies & lessons learned

4. **WAIT & COLLECT** - Use `background_output()` to gather all results

5. **SYNTHESIZE** - Cross-validate findings from ALL agents

### Common Mistake

❌ **Mistake**: "I'll spawn one agent to do the research"  
✅ **Correct**: "I'll spawn 8 agents, each focusing on one aspect"

**Remember**: The subagents are your workforce. You are the manager. Don't hire one person to do everything—hire specialists for each task.

### Pre-Launch Checklist (Before Spawning Agents)

Before you launch any agents, verify:

- [ ] I have identified **3-7 distinct research directions**
- [ ] For each direction, I have planned **2-4 specific angles**
- [ ] I will spawn **6-12+ agents total** (directions × angles)
- [ ] All agents will run with `run_in_background=True`
- [ ] Each agent prompt focuses on **ONE angle only**
- [ ] I have a plan to collect and synthesize all results

**If you can't check all boxes, STOP and redesign your approach.**

---

## Workflow (Multi-Agent Research Loop)

### Phase 1: Clarification & Direction Setting (Orchestrator)

**Step 1: Detect vagueness → request clarification**

If the prompt is too vague to search effectively, ask 2–5 clarification questions covering:
- Goal: what decision/action will this inform?
- Scope: which sub-area(s) matter and which don't?
- Time window: "latest" as of when? (date range)
- Region/context constraints
- Depth preference: quick overview vs deep dive

**Step 2: Initial broad scan (Orchestrator performs this)**

Generate 6-12 query variants and perform lightweight scanning to identify 3-7 distinct research directions.

For each direction, document:
- Direction name (1-2 words)
- Key question this direction answers
- Suggested agent specializations (see below)
- Priority level (high/medium/low)

**Step 3: Propose research plan to user**

Present:
- Identified directions with brief rationale
- Proposed agent assignments per direction
- Expected timeline
- Ask: "Which directions should we prioritize? Any angles we're missing?"

---

### Phase 2: Parallel Agent Deployment

**Step 4: Spawn research agents in parallel**

For EACH direction, spawn **2-4 specialized agents** simultaneously:

```python
# Example: Researching "GraphQL vs REST API performance"

# Direction A: GraphQL Performance - Docs/Benchmarks angle
task_A1 = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="GraphQL perf - official docs",
    prompt="""TASK: Deep research on GraphQL performance characteristics
RESEARCH_DIRECTION: GraphQL Performance Analysis
ANGLE: Official documentation and benchmarks
KEY_QUESTION: What are GraphQL's performance characteristics, caching strategies, and N+1 query solutions?

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Search for documentation, benchmarks, best practices
- webfetch: Fetch and read full content from URLs (NEVER rely on snippets)
- codesearch: Search for code examples of DataLoader, caching implementations

MUST_DO:
- Use websearch to find: official GraphQL docs, Apollo/Relay performance guides, benchmark studies
- For EACH promising result, use webfetch to read the FULL article/page
- Use codesearch to find DataLoader implementation examples
- Extract specific performance numbers, caching strategies, and N+1 solutions
- Include exact URLs and dates for every finding

SEARCH_QUERIES_TO_TRY:
- "GraphQL official documentation performance"
- "Apollo Client caching best practices 2024"
- "GraphQL vs REST benchmark study"
- "DataLoader batch loading implementation"

MUST_NOT_DO:
- NEVER rely on search result snippets alone - always fetch full content
- Don't cite secondary blog posts without checking primary sources
- Don't skip version dates on benchmarks

RETURN_FORMAT:
## Summary (2-3 sentences answering KEY_QUESTION)
## Key Findings (5-10 bullet points with inline citations [Source: link])
## Sources (full list: URL + title + date)
## Confidence Assessment (high/medium/low with rationale)
## Contradictions Found (if any)
## Open Questions"""
)

# Direction A: GraphQL Performance - Community angle
task_A2 = task(
    category="deep", 
    load_skills=["researcher"],
    run_in_background=True,
    description="GraphQL perf - community issues",
    prompt="""TASK: Deep research on GraphQL real-world performance issues
RESEARCH_DIRECTION: GraphQL Performance Analysis
ANGLE: Community discussions and production postmortems
KEY_QUESTION: What performance pitfalls do teams encounter with GraphQL in production?

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Search for Reddit, HN discussions, blog posts about GraphQL issues
- webfetch: Fetch and read full discussion threads and articles
- grep_app_searchGitHub: Search GitHub issues mentioning GraphQL performance problems
- codesearch: Search for GraphQL performance-related code and configurations

MUST_DO:
- Use grep_app_searchGitHub to find real issues: search "GraphQL performance" in repos
- Use websearch to find: Reddit threads, HN discussions, engineering blog postmortems
- For EACH promising discussion/article, use webfetch to read the FULL content
- Look for specific performance problems, solutions tried, and lessons learned
- Include exact URLs and dates for every finding
- Note both positive and negative experiences

SEARCH_QUERIES_TO_TRY:
- "GraphQL production issues reddit"
- "GraphQL performance problems github issues"
- "site:news.ycombinator.com GraphQL scaling"
- "GraphQL N+1 problem production postmortem"

MUST_NOT_DO:
- NEVER rely on search result snippets alone - always fetch full content
- Don't include speculative opinions without evidence
- Don't ignore negative experiences or failure stories

RETURN_FORMAT:
## Summary (2-3 sentences answering KEY_QUESTION)
## Key Findings (5-10 bullet points with inline citations [Source: link])
## Sources (full list: URL + title + date)
## Confidence Assessment (high/medium/low with rationale)
## Contradictions Found (if any)
## Open Questions"""
)

# Direction B: REST Performance
task_B1 = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="REST perf - docs and benchmarks",
    prompt="""TASK: Deep research on REST API performance characteristics
RESEARCH_DIRECTION: REST Performance Analysis
ANGLE: Documentation and benchmarks
KEY_QUESTION: What are REST's performance characteristics, caching mechanisms, and scalability patterns?

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Search for REST API best practices, HTTP caching, benchmark studies
- webfetch: Fetch and read full documentation and articles
- codesearch: Search for REST API implementation patterns, caching strategies

MUST_DO:
- Use websearch to find: HTTP/REST official specs, caching best practices, benchmark comparisons
- For EACH promising result, use webfetch to read the FULL content
- Use codesearch to find REST API optimization examples
- Extract specific performance characteristics and HTTP caching mechanisms
- Include exact URLs and dates for every finding

SEARCH_QUERIES_TO_TRY:
- "REST API performance best practices 2024"
- "HTTP caching REST API"
- "REST vs GraphQL performance benchmark"
- "REST API scalability patterns"

MUST_NOT_DO:
- NEVER rely on search result snippets alone
- Don't cite outdated sources without checking for newer information

RETURN_FORMAT:
## Summary (2-3 sentences answering KEY_QUESTION)
## Key Findings (5-10 bullet points with inline citations [Source: link])
## Sources (full list: URL + title + date)
## Confidence Assessment (high/medium/low with rationale)
## Contradictions Found (if any)
## Open Questions"""
)

task_B2 = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="REST perf - community experiences",
    prompt="""TASK: Deep research on REST production experiences
RESEARCH_DIRECTION: REST Performance Analysis
ANGLE: Community experiences and issues
KEY_QUESTION: What are the real-world experiences with REST API performance at scale?

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Search for community discussions, Reddit, HN, blog posts
- webfetch: Fetch and read full articles and discussions
- grep_app_searchGitHub: Search GitHub for REST API related issues

MUST_DO:
- Use websearch and grep_app_searchGitHub to find real production experiences
- For EACH promising source, use webfetch to read the FULL content
- Include exact URLs and dates for every finding

SEARCH_QUERIES_TO_TRY:
- "REST API production scaling issues"
- "REST vs GraphQL production experience"
- "site:reddit.com REST API performance"

MUST_NOT_DO:
- NEVER rely on search result snippets alone

RETURN_FORMAT:
## Summary (2-3 sentences answering KEY_QUESTION)
## Key Findings (5-10 bullet points with inline citations [Source: link])
## Sources (full list: URL + title + date)
## Confidence Assessment (high/medium/low with rationale)
## Contradictions Found (if any)
## Open Questions"""
)

# Direction C: Comparative Studies
task_C1 = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="GraphQL vs REST comparison",
    prompt="""TASK: Comparative research on GraphQL vs REST
RESEARCH_DIRECTION: Comparative Analysis
ANGLE: Benchmarks and migration studies
KEY_QUESTION: What do comparative studies and migration reports say about GraphQL vs REST trade-offs?

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Search for benchmark comparisons, migration case studies
- webfetch: Fetch and read full benchmark reports and case studies
- codesearch: Search for comparative implementations
- grep_app_searchGitHub: Search for migration examples and comparisons

MUST_DO:
- Use websearch to find: benchmark studies comparing GraphQL and REST, migration case studies
- For EACH promising result, use webfetch to read the FULL content
- Extract specific metrics, trade-offs, and migration costs
- Include exact URLs and dates for every finding

SEARCH_QUERIES_TO_TRY:
- "GraphQL vs REST benchmark 2024"
- "migrating from REST to GraphQL case study"
- "GraphQL REST performance comparison study"
- "REST to GraphQL migration experience report"

MUST_NOT_DO:
- NEVER rely on search result snippets alone
- Don't ignore studies that show REST outperforming GraphQL

RETURN_FORMAT:
## Summary (2-3 sentences answering KEY_QUESTION)
## Key Findings (5-10 bullet points with inline citations [Source: link])
## Sources (full list: URL + title + date)
## Confidence Assessment (high/medium/low with rationale)
## Contradictions Found (if any)
## Open Questions"""
)
```

**Agent Specialization Patterns:**

For each direction, assign agents with **complementary angles**:

| Angle | Focus | Typical Sources |
|-------|-------|-----------------|
| `docs` | Official documentation, specs, RFCs | Official docs, standards, API references |
| `papers` | Academic/technical research | arXiv, IEEE, ACM, Google Scholar |
| `community` | Real-world experiences, issues | GitHub issues, Reddit, HN, StackOverflow |
| `benchmarks` | Performance comparisons | Benchmark repos, load test results |
| `migration` | Migration guides, lessons learned | Migration docs, blog posts with before/after |

**Step 5: Monitor and collect results**

While agents work (typically 30-120 seconds):
1. Continue with other work or brief the user on progress
2. Periodically check completion: `background_output(task_id=task_A1.task_id, block=False)`
3. Collect all results once agents complete

---

### Phase 3: Synthesis & Validation (Orchestrator)

**Step 6: Cross-validate findings**

For each direction's findings:
- Compare results from multiple agents
- Identify agreements and contradictions
- Flag claims with only single-source support
- Note confidence levels per finding

**Validation Checklist:**
- [ ] Do agents agree on key facts?
- [ ] Are contradictions explained (different contexts, versions, use cases)?
- [ ] Is there at least one primary source per major claim?
- [ ] Are sources recent enough for the topic?

**Step 7: Synthesize final report**

Structure:
```markdown
# Research Synthesis: [Topic]

## Executive Summary
2-3 sentences on the overall landscape

## Direction A: [Name]
**Agents consulted**: [List agent angles]

### Consensus Findings
- Finding 1 (Confidence: High) - [Evidence]
- Finding 2 (Confidence: Medium) - [Evidence]

### Disputed/Issues
- Contradiction X: Agent A found [...] vs Agent B found [...]
- Likely explanation: [...]

### Open Questions
- [...]

## Direction B: [Name]
[Same structure]

## Comparative Analysis
[Cross-direction insights, trade-offs table]

## Recommendations
- For [use case A]: [direction X] appears best because [...]
- For [use case B]: consider [...]

## Next Steps
- Deep dive into [...] (recommended if [...])
- Validate [...] with additional primary sources
```

**Step 8: Present to user with options**

```
## Research Complete: [Topic]

### Key Findings Summary
[3-5 bullet points]

### Decisions Needed
1. Should we deep dive into [direction X]? It has conflicting reports that need resolution.
2. Are you interested in [aspect Y]? We didn't cover it in this round.
3. Do you need implementation examples for [approach Z]?

### Available Artifacts
- Full synthesis report (above)
- Raw agent findings: [available if needed]
- Source links: [compiled list]
```

---

### Phase 4: Iterative Deepening (Optional)

**Step 9: Handle user feedback**

Based on user response:
- If user wants deeper investigation: spawn new agents for specific subtopics
- If user wants alternative directions: repeat Phase 2 with new directions
- If user is satisfied: conclude and offer to save research artifacts

---

## Available Tools for Research Agents

Research agents MUST use the following tools to perform web research:

### Primary Research Tools
- **`websearch`**: General web search for finding sources
  - Use for: Initial discovery, finding documentation, blog posts, forums
  - Example: Search "GraphQL performance best practices 2024"

- **`webfetch`**: Fetch specific URLs for deep reading
  - Use for: Reading full articles, documentation pages, GitHub issues
  - MUST fetch original sources, not rely on search snippets

- **`codesearch`**: Search for code examples and implementations
  - Use for: Finding code patterns, configuration examples, library usage

### Specialized Tools
- **`context7_resolve-library-id`** + **`context7_query-docs`**: Query technical documentation
  - Use for: Official library/framework docs, API references
  - Example: Query specific function usage or configuration options

- **`grep_app_searchGitHub`**: Search GitHub repositories
  - Use for: Finding real-world code examples, issues, PRs
  - Use `repo:` filter to target specific organizations

### Tool Usage Rules
1. **ALWAYS start with search**: Use `websearch` or `codesearch` to discover sources
2. **NEVER rely on snippets**: Always use `webfetch` to read full content
3. **Include source links**: Every finding must include the URL where it was found
4. **Check dates**: Note publication/last-updated dates for time-sensitive claims

---

## Agent Task Template

**FOR ORCHESTRATOR USE**: When spawning research agents, use this template.

**⚠️ IMPORTANT**: Each agent prompt must be **FOCUSED ON ONE ANGLE ONLY**. Don't give an agent multiple directions to research.

### Template

```python
task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="[Direction] - [Angle]",
    prompt="""TASK: Deep research on [specific topic]
RESEARCH_DIRECTION: [Direction name from orchestrator plan]
ANGLE: [Specialization angle: docs/papers/community/benchmarks/migration]
KEY_QUESTION: [The specific question this agent must answer - ONE question only]

CONTEXT:
[Background from orchestrator's initial scan]

⚠️ SCOPE LIMITATION - IMPORTANT:
You are researching ONLY this specific angle. Do NOT:
- Research other directions (that's for other agents)
- Try to cover the entire topic comprehensively
- Spawn additional agents

Your job is to go DEEP on this ONE angle, not WIDE across all angles.

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Use this to search the web for sources, documentation, discussions
- webfetch: Use this to fetch and read full content from URLs (NEVER rely on search snippets)
- codesearch: Use this to search for code examples and technical implementations
- grep_app_searchGitHub: Use this to search GitHub repos for issues, examples, real-world usage

MUST_DO:
- Focus ONLY on your assigned ANGLE
- Use websearch/codesearch to find 8-15 relevant sources
- For EACH promising source, use webfetch to read the FULL content (not just snippets)
- Extract specific claims, quotes, and data points with context
- Include exact URLs and dates for every finding
- Search from multiple independent sources

MUST_NOT_DO:
- Do NOT research other directions (other agents handle those)
- Do NOT try to be comprehensive across the whole topic
- NEVER rely on search result snippets or summaries alone
- Don't just list sources without extracting specific findings
- Don't ignore contradictory evidence

SEARCH_STRATEGY_BY_ANGLE:
- docs: Search for "official documentation", "specification", "API reference", "changelog"
- papers: Search for "arxiv", "research paper", "benchmark", "study", "survey"
- community: Search for "reddit", "github issues", "stackoverflow", "experience"
- benchmarks: Search for "benchmark comparison", "performance test", "load test results"

RETURN_FORMAT:
## Summary (2-3 sentences answering KEY_QUESTION)
## Key Findings (5-10 bullet points with inline citations [Source: link])
## Sources (full list with dates)
## Confidence Assessment (high/medium/low with rationale)
## Contradictions Found (if any)
## Open Questions (gaps in available information)
"""
)
```

### Example: Good vs Bad Agent Prompts

❌ **BAD** (too broad - agent will do shallow work):
```
RESEARCH_DIRECTION: GraphQL vs REST Comparison
ANGLE: Everything
KEY_QUESTION: Compare GraphQL and REST in all aspects
```

✅ **GOOD** (focused - agent can go deep):
```
RESEARCH_DIRECTION: GraphQL Performance
ANGLE: Official documentation and benchmarks
KEY_QUESTION: What are GraphQL's caching mechanisms and performance characteristics according to official sources?
```

---

## Quality Standards

### For Orchestrator
- [ ] Clear direction decomposition
- [ ] Appropriate agent specialization per direction
- [ ] All agents launched in parallel (no sequential waiting)
- [ ] Results collected and validated
- [ ] Contradictions acknowledged, not suppressed
- [ ] Confidence levels assigned based on source quality

### For Research Agents
- [ ] **Used websearch/codesearch to find sources** (not skipped)
- [ ] **Used webfetch to read full content** (never relied on snippets)
- [ ] Dates included for all time-sensitive claims
- [ ] At least 3-5 independent sources per major finding
- [ ] Both supporting and contradicting evidence reported
- [ ] PDFs converted to text when relevant

### For Synthesis
- [ ] Multi-agent findings cross-referenced
- [ ] Disagreements explained, not buried
- [ ] Actionable recommendations with clear rationale
- [ ] Next steps prioritized by user goals

---

## Tool Usage Guide

### Critical: Research Agents MUST Use These Tools

Every research agent MUST actively use the available tools. **Not using tools is a failure mode.**

**Step-by-step tool usage:**

1. **Discovery Phase** - Use search tools:
   ```python
   websearch(query="your search terms")
   codesearch(query="code patterns", language=["Python", "JavaScript"])
   grep_app_searchGitHub(query="error pattern", repo="organization/repo")
   ```

2. **Fetch Phase** - ALWAYS fetch full content:
   ```python
   # NEVER rely on search snippets - fetch the full page
   webfetch(url="https://example.com/article", format="markdown")
   ```

3. **Extract Phase** - Read and extract findings:
   - Read the fetched content thoroughly
   - Extract specific claims, quotes, numbers
   - Note the URL and date

### Non-negotiable: Fetch Originals
Never rely on search result snippets. Agents MUST:
1. **Search first**: Use `websearch`, `codesearch`, or `grep_app_searchGitHub`
2. **Fetch full content**: Use `webfetch` to read the actual page/article
3. **Extract claims**: Pull out specific quotes, numbers, findings
4. **Record metadata**: Save URL, title, date for every source

**Example workflow:**
```python
# 1. Search for sources
results = websearch(query="GraphQL performance benchmark 2024")

# 2. For each promising result, FETCH it
for result in results[:5]:
    content = webfetch(url=result.url, format="markdown")
    # 3. Read and extract specific findings
    # 4. Record with citation
```

### PDF Handling
- Download to `/tmp` workspace: `workdir=$(scripts/mk_workdir.sh)`
- Convert: `scripts/pdf_to_text.sh paper.pdf paper.txt`
- Search within extracted text

### Parallel Agent Management
```python
# Launch phase
tasks = {}
for direction in directions:
    for angle in direction.angles:
        task_result = task(..., run_in_background=True)
        tasks[f"{direction.name}-{angle}"] = task_result.task_id

# Collection phase
results = {}
for name, task_id in tasks.items():
    output = background_output(task_id=task_id, block=True)
    results[name] = output
```

---

## Example: Complete Research Session

**User Request**: "Should we migrate from REST to GraphQL for our mobile API?"

**Orchestrator Response**:
1. Clarify: Ask about current pain points, team size, timeline
2. Plan: Identify 4 directions:
   - A: GraphQL mobile performance
   - B: Migration complexity/cost  
   - C: Team learning curve
   - D: Long-term ecosystem trends
3. Deploy: Spawn 8 agents (2 per direction, different angles)
4. Synthesize: Cross-validate findings, note contradictions
5. Report: "GraphQL shows 30% payload reduction but 2-3 week migration cost..."
6. Iterate: User asks about caching → spawn 2 more agents on caching specifics

---

## Anti-Patterns (AVOID)

| Anti-Pattern | Why It's Bad | Solution |
|--------------|--------------|----------|
| **⚠️ Single agent doing everything** | Defeats multi-agent purpose; one agent cannot cover all angles comprehensively | Spawn 6-12+ agents, each with ONE specific angle |
| **⚠️ Asking one agent to "research all directions"** | Agent will do shallow work or get overwhelmed | YOU decompose directions; spawn separate agents per direction |
| Sequential agent execution | Defeats parallel efficiency | Always use `run_in_background=True` |
| Overlapping agent scopes | Wasted effort, confusing synthesis | Give each agent distinct ANGLE |
| Suppressing contradictions | Creates false confidence | Highlight disagreements with analysis |
| Too many agents per direction | Diminishing returns, synthesis burden | Max 3-4 agents per direction |
| Single-source claims | Unreliable | Require multiple independent sources |
| Ignoring agent findings | Wasted work | All agent outputs must inform synthesis |

### The "Single Agent Trap" - Most Common Error

**Scenario**: User asks "Should we use GraphQL or REST?"

❌ **WRONG approach** (don't do this):
```python
# DON'T DO THIS - One agent doing everything
task(
    description="Research GraphQL vs REST",
    prompt="""Research everything about GraphQL vs REST:
- GraphQL performance
- REST performance  
- Migration costs
- Community opinions
- Benchmarks
..."""
)
```

✅ **CORRECT approach** (do this):
```python
# DO THIS - Multiple specialized agents in parallel

# Direction A: GraphQL Performance (2 agents)
task_A1 = task(..., description="GraphQL - docs & benchmarks", run_in_background=True)
task_A2 = task(..., description="GraphQL - community issues", run_in_background=True)

# Direction B: REST Performance (2 agents)  
task_B1 = task(..., description="REST - docs & benchmarks", run_in_background=True)
task_B2 = task(..., description="REST - community issues", run_in_background=True)

# Direction C: Comparative Studies (2 agents)
task_C1 = task(..., description="Benchmarks comparison", run_in_background=True)
task_C2 = task(..., description="Migration case studies", run_in_background=True)

# Collect all results
results_A1 = background_output(task_id=task_A1.task_id)
results_A2 = background_output(task_id=task_A2.task_id)
# ... etc

# Synthesize findings from ALL agents
```

**Why the wrong approach fails**:
- One agent cannot comprehensively research multiple complex topics
- No cross-validation of findings
- No parallel execution = slow
- Agent may skip important angles

**Why the correct approach works**:
- Each agent focuses deeply on ONE angle
- Multiple agents = multiple perspectives
- Parallel execution = fast
- You synthesize diverse findings for comprehensive view

---

## Legacy: Single-Agent Mode

For simple research tasks that don't require multi-angle coverage, you can still use the original single-agent workflow:

1. Clarify the question
2. Broad scan (6-12 query variants)
3. Deep dive (1-3 subtopics)
4. Synthesize and report

However, for complex decisions with trade-offs, prefer the multi-agent approach above.

---

## Reference Materials

- **Query patterns & source triage**: See `references/query-playbook.md`
- **Complete Orchestrator example**: See `examples/orchestrator-example.md` for a full walkthrough of correct multi-agent research execution

## Quick Reminder

Before starting research:
1. ✓ Decompose into 3-7 directions
2. ✓ Plan 6-12+ parallel agents
3. ✓ Each agent = ONE angle only
4. ✓ Synthesize all findings

**You are the conductor, not the orchestra!**
