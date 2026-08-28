---
name: researcher
description: "Adaptive evidence-backed research for requests that explicitly need research, a survey, or a source-backed comparison. Route local inspection to explore, external sources to librarian, and difficult unresolved reasoning to general; start small and expand only with user approval."
---

# Researcher (Multi-Agent Iterative Web Research)

## ⚠️ CRITICAL: READ THIS FIRST

**YOU ARE THE ORCHESTRATOR. DELEGATION IS A TOOL, NOT A TARGET.**

❌ **WRONG**: Launching a large swarm before checking whether local or primary-source evidence already answers the question
✅ **CORRECT**: Starting with 1-2 role-appropriate agents, synthesizing their evidence, and expanding only when necessary

Your job is to minimize research cost while preserving evidence quality. The orchestrator owns scoping, routing, synthesis, and stopping decisions.

---

## Architecture Overview

This skill uses a **multi-agent collaborative architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR (You)                       │
│         - Identifies the smallest decisive questions        │
│         - Starts 1-2 role-appropriate research agents       │
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
- **DECOMPOSE** only as far as needed to identify decisive, non-overlapping questions
- **START SMALL** with 1-2 specialized agents in parallel
- **COORDINATE**: Each agent gets ONE specific angle only
- **SYNTHESIZE**: Combine findings from all agents, cross-validate
- **STOP** once primary-source evidence resolves the question

**🤖 Research Agents（研究员）:**
- Each agent focuses on **ONE** specific subtopic/angle
- Agents run independently in parallel (`background=true`)
- Agents **DO NOT** spawn other agents - that's YOUR job
- Agents return structured findings for YOU to synthesize

### Key Numbers to Remember

| Metric | Target |
|--------|--------|
| Focused first wave | 1-2 agents |
| Maximum without approval | 4 total agents, at most 1 `general` |
| Deep mode | 5-6 preferred, only after explicit approval |
| Sequential agents | 0 (all parallel) |

An approved count is a ceiling, not a quota. A second wave always requires explicit user approval.

### Agent Routing

| Work | Agent | Default use |
|------|-------|-------------|
| Local repository search, file discovery, pinned source inspection | `explore` | First choice for local evidence |
| Official docs, standards, releases, GitHub source/issues, dependency behavior | `librarian` | First choice for external research |
| Difficult cross-domain reasoning, unresolved contradictions, complex feasibility analysis | `general` | Escalation only |

Do not mention underlying model names; assignments may change. Do not use `general` for routine web search or local code discovery. The orchestrator performs final synthesis.

**Research Agents（研究员）:**
- Each agent focuses on ONE specific subtopic/angle
- Agents run independently and in parallel (`background=true`)
- Agents fetch original sources (not just snippets)
- Agents return structured findings with evidence links

---

## 🚨 Orchestrator Responsibilities (READ CAREFULLY)

### What YOU Must Do (The Orchestrator)

When user asks for research, **YOU** must:

1. **DECOMPOSE** - Identify the smallest set of independent questions that determine the conclusion.

2. **ROUTE THE FIRST WAVE** - Launch 1-2 role-appropriate agents in parallel.
   ```python
   # WRONG - Don't do this:
   subagent(agent="general", description="Research everything", prompt="Research GraphQL vs REST...")
   
   # CORRECT - Local evidence plus external primary sources:
   subagent(agent="explore", description="Inspect current implementation", prompt="...", background=True)
   subagent(agent="librarian", description="Check official evidence", prompt="...", background=True)
   ```

3. **ASSIGN SPECIFIC ANGLES** - Each agent gets one narrow, non-overlapping question and the minimum context needed to answer it.

4. **WAIT & COLLECT** - Background subagents notify you automatically when they finish (no polling needed). Collect all results once the notifications arrive.

5. **SYNTHESIZE AND STOP** - Cross-validate findings and stop when primary-source evidence answers the question.

6. **EXPAND ONLY WITH APPROVAL** - Explain the unresolved question and proposed added cost before every second wave. More than 4 total agents or more than 1 `general` agent requires explicit approval.

### Common Mistake

❌ **Mistake**: "More agents automatically mean better research"
✅ **Correct**: "I'll use the smallest role-appropriate first wave and expand only if evidence remains materially incomplete"

**Remember**: The subagents are your workforce. You are the manager. Don't hire one person to do everything—hire specialists for each task.

### Pre-Launch Checklist (Before Spawning Agents)

Before you launch any agents, verify:

- [ ] I have identified the smallest decisive questions
- [ ] I have chosen the least expensive capable agent for each question
- [ ] I will start with **1-2 agents total** unless the user approved deep mode
- [ ] All agents will run with `background=true`
- [ ] Each agent prompt focuses on **ONE angle only**
- [ ] I have a plan to collect and synthesize all results (completion notifications)
- [ ] Any second wave or budget above 4 agents has explicit user approval

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

Run a lightweight scan and inspect available local evidence before delegation. Identify only the questions whose answers can change the conclusion.

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

In focused mode, spawn 1-2 role-appropriate agents. The extended example below illustrates an explicitly approved deep-mode comparison; it is not the default budget.

```python
# Example: Researching "GraphQL vs REST API performance"

# Direction A: GraphQL Performance - Docs/Benchmarks angle
subagent(
    agent="librarian",
    background=True,
    description="GraphQL perf - official docs",
    prompt="""TASK: Deep research on GraphQL performance characteristics
RESEARCH_DIRECTION: GraphQL Performance Analysis
ANGLE: Official documentation and benchmarks
KEY_QUESTION: What are GraphQL's performance characteristics, caching strategies, and N+1 query solutions?

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Search for documentation, benchmarks, best practices
- webfetch: Fetch and read full content from URLs (NEVER rely on snippets)

MUST_DO:
- Use websearch to find: official GraphQL docs, Apollo/Relay performance guides, benchmark studies
- For EACH promising result, use webfetch to read the FULL article/page
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
subagent(
    agent="librarian",
    background=True,
    description="GraphQL perf - community issues",
    prompt="""TASK: Deep research on GraphQL real-world performance issues
RESEARCH_DIRECTION: GraphQL Performance Analysis
ANGLE: Community discussions and production postmortems
KEY_QUESTION: What performance pitfalls do teams encounter with GraphQL in production?

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Search for Reddit, HN discussions, blog posts about GraphQL issues
- webfetch: Fetch and read full discussion threads and articles

MUST_DO:
- Use websearch to find GitHub issues: search "GraphQL performance" with site:github.com
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
subagent(
    agent="librarian",
    background=True,
    description="REST perf - docs and benchmarks",
    prompt="""TASK: Deep research on REST API performance characteristics
RESEARCH_DIRECTION: REST Performance Analysis
ANGLE: Documentation and benchmarks
KEY_QUESTION: What are REST's performance characteristics, caching mechanisms, and scalability patterns?

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Search for REST API best practices, HTTP caching, benchmark studies
- webfetch: Fetch and read full documentation and articles

MUST_DO:
- Use websearch to find: HTTP/REST official specs, caching best practices, benchmark comparisons
- For EACH promising result, use webfetch to read the FULL content
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

subagent(
    agent="librarian",
    background=True,
    description="REST perf - community experiences",
    prompt="""TASK: Deep research on REST production experiences
RESEARCH_DIRECTION: REST Performance Analysis
ANGLE: Community experiences and issues
KEY_QUESTION: What are the real-world experiences with REST API performance at scale?

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Search for community discussions, Reddit, HN, blog posts
- webfetch: Fetch and read full articles and discussions

MUST_DO:
- Use websearch to find real production experiences (including site:github.com issues)
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
subagent(
    agent="librarian",
    background=True,
    description="GraphQL vs REST comparison",
    prompt="""TASK: Comparative research on GraphQL vs REST
RESEARCH_DIRECTION: Comparative Analysis
ANGLE: Benchmarks and migration studies
KEY_QUESTION: What do comparative studies and migration reports say about GraphQL vs REST trade-offs?

AVAILABLE TOOLS (YOU MUST USE THESE):
- websearch: Search for benchmark comparisons, migration case studies
- webfetch: Fetch and read full benchmark reports and case studies

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
2. Background subagents notify you automatically when they complete - no polling needed
3. Collect all results once the completion notifications arrive

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
- If user wants deeper investigation: propose a bounded second wave and wait for explicit approval
- If user wants alternative directions: propose the new scope and added cost before repeating Phase 2
- If user is satisfied: conclude and offer to save research artifacts

If the user asks to stop, immediately interrupt every active child session and launch no more agents. Treat any user-provided budget or agent limit as a hard ceiling.

---

## Available Tools for Research Agents

Use tools according to the selected agent role. Do not force local exploration agents into external web research.

### Primary Research Tools
- **`explore`**: Use repository search and file-reading tools for local code, configuration, and pinned sources.
- **`librarian`**: Use external search and fetch tools for official docs, standards, releases, repositories, issues, and PRs.
- **`general`**: Use task-appropriate tools only for the unresolved reasoning scope assigned to it.

### Specialized Tools
Follow current environment requirements for library documentation and available search integrations. Tool names and availability may change.

### Tool Usage Rules
1. **Search locally first when applicable**: Prefer pinned implementation evidence over generic web results.
2. **Fetch originals for external claims**: Never rely on search snippets.
3. **Include source links**: Every finding must include the URL where it was found
4. **Check dates**: Note publication/last-updated dates for time-sensitive claims

---

## Agent Task Template

**FOR ORCHESTRATOR USE**: When spawning research agents, use this template.

**⚠️ IMPORTANT**: Each agent prompt must be **FOCUSED ON ONE ANGLE ONLY**. Don't give an agent multiple directions to research.

### Template

```python
subagent(
    agent=selected_agent,
    background=True,
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

AVAILABLE TOOLS:
- Use the tools appropriate for the selected agent role and current environment.
- For external research, search for and fetch original sources; never rely on snippets.

MUST_DO:
- Focus ONLY on your assigned ANGLE
- In focused mode, use 2-4 relevant primary sources; expand only when evidence conflicts or the user approved deep mode
- For each external source used as evidence, read the full relevant content rather than a search snippet
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
- [ ] **Used websearch to find sources** (not skipped)
- [ ] **Used webfetch to read full content** (never relied on snippets)
- [ ] Dates included for all time-sensitive claims
- [ ] Major claims have enough independent evidence for the requested depth, including a primary source when available
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
1. **Search first**: Use `websearch` to discover sources
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
# Launch phase: spawn one background subagent per direction x angle
for direction in directions:
    for angle in direction.angles:
        subagent(
            agent=route_agent(angle),
            background=True,
            description=f"{direction.name}-{angle}",
            prompt=build_agent_prompt(direction, angle),
        )

# Collection phase: background subagents notify you automatically
# when they complete - synthesize results as the notifications arrive.
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
3. Deploy: Propose a bounded role-routed plan and obtain approval before deep-mode delegation
4. Synthesize: Cross-validate findings, note contradictions
5. Report: "GraphQL shows 30% payload reduction but 2-3 week migration cost..."
6. Iterate: User asks about caching → spawn 2 more agents on caching specifics

---

## Anti-Patterns (AVOID)

| Anti-Pattern | Why It's Bad | Solution |
|--------------|--------------|----------|
| **⚠️ Launching a swarm by default** | Burns budget before the decisive questions are known | Start with 1-2 role-appropriate agents and expand only with approval |
| **⚠️ Asking one agent to "research all directions"** | Agent will do shallow work or get overwhelmed | YOU decompose directions; spawn separate agents per direction |
| Sequential agent execution | Defeats parallel efficiency | Always use `background=True` |
| Overlapping agent scopes | Wasted effort, confusing synthesis | Give each agent distinct ANGLE |
| Suppressing contradictions | Creates false confidence | Highlight disagreements with analysis |
| Too many agents per direction | Diminishing returns, synthesis burden | Use one agent per necessary angle unless the user approves deeper coverage |
| Single-source claims | Unreliable | Require multiple independent sources |
| Ignoring agent findings | Wasted work | All agent outputs must inform synthesis |

### The "Single Agent Trap" - Most Common Error

**Scenario**: User asks "Should we use GraphQL or REST?"

❌ **WRONG approach** (don't do this):
```python
# DON'T DO THIS - One agent doing everything
subagent(
    agent="general",
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
# DEEP MODE ONLY - Use a bounded approved plan with specialized agents

# Direction A: GraphQL Performance (2 agents)
subagent(agent="librarian", description="GraphQL - docs & benchmarks", prompt="...", background=True)
subagent(agent="librarian", description="GraphQL - community issues", prompt="...", background=True)

# Direction B: REST Performance (2 agents)  
subagent(agent="librarian", description="REST - docs & benchmarks", prompt="...", background=True)
subagent(agent="librarian", description="REST - community issues", prompt="...", background=True)

# Direction C: Comparative Studies (2 agents)
subagent(agent="librarian", description="Benchmarks comparison", prompt="...", background=True)
subagent(agent="librarian", description="Migration case studies", prompt="...", background=True)

# Collect all results as completion notifications arrive

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
2. Lightweight scan of local and primary-source evidence
3. Deep dive (1-3 subtopics)
4. Synthesize and report

However, for complex decisions with trade-offs, prefer the multi-agent approach above.

---

## Reference Materials

- **Query patterns & source triage**: See `references/query-playbook.md`
- **Approved deep-mode example**: See `examples/orchestrator-example.md` only when the user explicitly approved a broad comparison above the focused-mode budget

## Quick Reminder

Before starting research:
1. ✓ Identify the smallest decisive questions
2. ✓ Route 1-2 first-wave agents by capability
3. ✓ Each agent = ONE angle only
4. ✓ Synthesize before requesting any second wave

**You are the conductor, not the orchestra!**
