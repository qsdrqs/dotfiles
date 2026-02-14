# Multi-Agent Research Example: Complete Orchestrator Walkthrough

This example demonstrates the **correct** way to use the researcher skill as an Orchestrator.

## Scenario

**User Request**: "Should our team migrate from REST to GraphQL for our mobile API?"

## Step 1: Decompose into Directions (Orchestrator)

Identify 4 distinct research directions:

| Direction | Key Question | Angles Needed |
|-----------|--------------|---------------|
| A. GraphQL Performance | How does GraphQL perform on mobile? | Docs, Community issues |
| B. REST Performance | How does REST compare for mobile? | Docs, Community experience |
| C. Migration Cost | What's the cost to migrate? | Case studies, Tooling |
| D. Team Learning | How steep is the learning curve? | Tutorials complexity, Training resources |

**Total agents to spawn**: 8 (2 per direction)

## Step 2: Launch All Agents in Parallel (Orchestrator)

```python
# Store task IDs to collect later
tasks = {}

# Direction A: GraphQL Performance
tasks['A1'] = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="GraphQL perf - docs & benchmarks",
    prompt="""TASK: Research GraphQL mobile performance - official sources
RESEARCH_DIRECTION: GraphQL Mobile Performance
ANGLE: Official documentation and benchmarks
KEY_QUESTION: What are GraphQL's performance characteristics for mobile apps according to official sources?

[Rest of prompt with MUST_DO, AVAILABLE TOOLS, etc.]
"""
)

tasks['A2'] = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="GraphQL perf - community issues",
    prompt="""TASK: Research GraphQL mobile performance - real world issues
RESEARCH_DIRECTION: GraphQL Mobile Performance
ANGLE: Community discussions and production issues
KEY_QUESTION: What performance problems do teams encounter with GraphQL on mobile in production?

[Rest of prompt...]
"""
)

# Direction B: REST Performance
tasks['B1'] = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="REST perf - docs & benchmarks",
    prompt="""TASK: Research REST mobile performance - official sources
RESEARCH_DIRECTION: REST Mobile Performance
ANGLE: Official documentation and HTTP caching
KEY_QUESTION: What are REST's performance characteristics and caching mechanisms for mobile?

[Rest of prompt...]
"""
)

tasks['B2'] = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="REST perf - community experience",
    prompt="""TASK: Research REST mobile performance - real world experience
RESEARCH_DIRECTION: REST Mobile Performance
ANGLE: Community production experience
KEY_QUESTION: How do teams optimize REST APIs for mobile in production?

[Rest of prompt...]
"""
)

# Direction C: Migration Cost
tasks['C1'] = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="Migration - case studies",
    prompt="""TASK: Research REST to GraphQL migration experiences
RESEARCH_DIRECTION: Migration Cost and Complexity
ANGLE: Migration case studies and reports
KEY_QUESTION: What do case studies say about the effort and cost to migrate from REST to GraphQL?

[Rest of prompt...]
"""
)

tasks['C2'] = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="Migration - tooling & automation",
    prompt="""TASK: Research migration tooling and automation
RESEARCH_DIRECTION: Migration Cost and Complexity
ANGLE: Available tools and automation
KEY_QUESTION: What tools and automation exist to help migrate from REST to GraphQL?

[Rest of prompt...]
"""
)

# Direction D: Learning Curve
tasks['D1'] = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="Learning - complexity & tutorials",
    prompt="""TASK: Research GraphQL learning complexity
RESEARCH_DIRECTION: Team Learning Curve
ANGLE: Documentation complexity and tutorial quality
KEY_QUESTION: How complex is GraphQL to learn compared to REST, based on official learning resources?

[Rest of prompt...]
"""
)

tasks['D2'] = task(
    category="deep",
    load_skills=["researcher"],
    run_in_background=True,
    description="Learning - training resources",
    prompt="""TASK: Research GraphQL training resources availability
RESEARCH_DIRECTION: Team Learning Curve
ANGLE: Training resources and community support
KEY_QUESTION: What training resources, courses, and community support exist for learning GraphQL?

[Rest of prompt...]
"""
)

print(f"Launched {len(tasks)} agents in parallel")
```

## Step 3: Inform User

```
I've launched 8 research agents to investigate your question from multiple angles:

**Direction A: GraphQL Performance** (2 agents)
- Agent A1: Official documentation & benchmarks
- Agent A2: Community issues & real-world problems

**Direction B: REST Performance** (2 agents)
- Agent B1: Official docs & HTTP caching
- Agent B2: Community production experience

**Direction C: Migration Cost** (2 agents)
- Agent C1: Migration case studies
- Agent C2: Tools & automation

**Direction D: Learning Curve** (2 agents)
- Agent D1: Documentation complexity
- Agent D2: Training resources

This will take about 60-90 seconds. I'll synthesize findings from all agents once they're complete.
```

## Step 4: Collect Results (Orchestrator)

```python
import time

# Wait a bit for agents to start working
time.sleep(5)

# Collect all results
results = {}
for name, task_obj in tasks.items():
    print(f"Collecting results from Agent {name}...")
    results[name] = background_output(task_id=task_obj.task_id, block=True)
    print(f"✓ Agent {name} complete")

print(f"\nCollected results from all {len(results)} agents")
```

## Step 5: Synthesize Findings (Orchestrator)

```python
# Cross-validate and synthesize
synthesis = """
# Research Synthesis: REST vs GraphQL for Mobile API

## Executive Summary
Based on findings from 8 parallel research agents investigating 4 directions, 
GraphQL offers payload efficiency benefits but requires significant migration 
investment and learning time.

## Direction A: GraphQL Performance
**Agents consulted**: Official docs (A1), Community issues (A2)

### Consensus Findings
- **Payload size**: 30-50% smaller than REST for complex queries (Agent A1 - High confidence)
- **N+1 problem**: Well-documented issue with DataLoader as solution (Agents A1, A2 agree)
- **Caching**: More complex than REST HTTP caching (Agent A1 - Medium confidence)

### Disputed/Issues
- Performance impact on low-end devices: Agent A1 found optimistic benchmarks, 
  Agent A2 found real-world reports of slow parsing on older phones
- Likely explanation: Benchmarks use modern devices; real users have varied hardware

## Direction B: REST Performance
**Agents consulted**: Official docs (B1), Community experience (B2)

### Consensus Findings
- **HTTP caching**: Mature and well-supported on mobile (Agent B1 - High confidence)
- **Over-fetching**: Common problem with mobile REST APIs (Agent B2 - High confidence)
- **Predictable**: Developers know how to optimize REST (Agent B2)

## Direction C: Migration Cost
**Agents consulted**: Case studies (C1), Tooling (C2)

### Consensus Findings
- **Timeline**: 2-4 weeks for simple APIs, 2-3 months for complex ones (Agent C1 - Medium confidence)
- **Tools**: Limited automated migration tools available (Agent C2)
- **Risk**: Several postmortems of failed migrations due to complexity (Agent C1)

## Direction D: Learning Curve
**Agents consulted**: Docs complexity (D1), Training (D2)

### Consensus Findings
- **GraphQL complexity**: Higher initial learning curve than REST (Agent D1)
- **Training**: Good resources available from Apollo, GraphQL.org (Agent D2)
- **Team readiness**: 1-2 weeks for basic proficiency (Agents D1, D2 agree)

## Comparative Analysis

| Factor | GraphQL | REST | Notes |
|--------|---------|------|-------|
| Payload efficiency | ✓✓✓ | ✓ | Significant win for complex data |
| Caching | ✓ | ✓✓✓ | REST has mature HTTP caching |
| Migration cost | -- | N/A | 2-4 weeks minimum |
| Learning curve | -- | ✓✓ | GraphQL more complex |
| Mobile optimization | ✓✓ | ✓ | GraphQL designed for mobile |

## Recommendations

**If your API has complex, nested relationships**: Consider GraphQL
- The payload efficiency gains are significant
- Worth the migration cost if API complexity is high

**If your API is simple CRUD**: Stick with REST
- Migration cost outweighs benefits
- Team already knows REST

**If you decide to migrate**:
1. Start with a pilot endpoint (not full migration)
2. Invest in training (2 weeks dedicated learning)
3. Use Apollo Client for caching layer
4. Plan for 2-4 weeks migration timeline

## Next Steps

Would you like me to:
1. Deep dive into specific GraphQL caching strategies?
2. Research specific migration tools for your tech stack?
3. Find more case studies from teams similar to yours?
"""

print(synthesis)
```

## Key Takeaways

1. **Decomposed** the question into 4 distinct directions
2. **Spawned 8 agents** in parallel (2 per direction with different angles)
3. **Each agent** had a specific, narrow focus
4. **Collected** all results before synthesizing
5. **Cross-validated** findings from multiple agents
6. **Presented** a comprehensive report with recommendations

This is how the researcher skill is designed to work!
