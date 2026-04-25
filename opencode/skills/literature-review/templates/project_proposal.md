<!--
Template consumed by the literature-review skill at Phase 6 when the user
selected output_type = "project proposal" in Phase 0.

Structure is a hybrid of NSF PAPPG 24-1 Project Description (Chapter II)
and ERC Starting/Consolidator Grant Part B1 (5 pp extended synopsis) +
Part B2 (14 pp scientific proposal). Use the sections that apply to the
user's actual funding target; keep both sets here so a single draft covers
both audiences. Sections marked "(NSF)" or "(ERC)" are specific to one
scheme; unmarked sections are shared.

Critical style rules:
  - NSF: URLs are PROHIBITED in the Project Description. Cite via BibTeX only.
  - ERC: State-of-the-Art MUST be CRITIQUE-style. For each major line of
    prior work, name the specific gap and why existing approaches are
    insufficient. Not a summary.
  - Both: every citation traces to a Zotero entry in Stage B; BibTeX keys
    must match.

Primary sources:
  NSF PAPPG 24-1: https://www.nsf.gov/policies/pappg/24-1/
  ERC 2025 guide: https://erc.europa.eu/sites/default/files/2025-03/How_to_write_your_proposal_2025.pdf
-->

# {{PROPOSAL_TITLE}}

PI: {{PI_NAME}}, {{AFFILIATION}}
Submitted to: {{FUNDING_SCHEME}} (NSF CISE / ERC-StG / ERC-CoG / ...)
Date: {{DATE}}

---

## 1. Overview / Project Summary

One page for NSF Project Summary (separate document); first 2-3 paragraphs
of ERC B1.

- **Problem**: {{one-sentence problem statement}}.
- **Gap in prior work**: {{one-sentence identification of what is missing}}.
- **Proposed approach**: {{one-sentence method summary}}.
- **Expected contributions**: {{2-3 enumerated contributions}}.
- **Intellectual Merit** (NSF, mandatory): {{explicit statement of how the
  project advances knowledge}}.
- **Broader Impacts** (NSF, mandatory): {{education, outreach, diversity,
  dissemination impact}}.
- **Ground-breaking / Ambitious / Feasible** (ERC 2025, mandatory):
  {{one paragraph arguing against each criterion}}.

---

## 2. State of the Art and Related Work

**(ERC framing required here: CRITIQUE, not summary.)**

Pull from `$LITREV_WORKDIR/related_work.md`. Must cluster the literature into
2-4 thematic groups derived from the comparison matrix. For each group:

### 2.{{N}} {{Theme name}}

Prior line of work: {{1-2 sentence summary of the approach family, with
2-5 citations to representative papers.}}

**Specific gap**: {{what these methods fail to address, with evidence from
the author-acknowledged limitations column of the matrix. One concrete gap,
not a platitude like "needs more research".}}

**Why existing approaches are insufficient for our goal**: {{link the gap
to the project's objectives. This is the critique step ERC demands.}}

### 2.{{M}} Positioning of the Proposed Work

One paragraph explicitly contrasting this proposal against each theme group
above. Name the specific design choice that differentiates this work (e.g.
"unlike {{theme 1}} which requires paired data, we leverage ...").

---

## 3. Research Objectives and Hypotheses

Numbered objectives. Each objective must be falsifiable (has a pass/fail
condition) and mapped to a concrete deliverable.

- **O1**: {{objective 1}}. Success criterion: {{measurable test}}.
- **O2**: {{objective 2}}. Success criterion: {{measurable test}}.
- **O3**: {{objective 3}}. Success criterion: {{measurable test}}.

Relate each objective to the gap named in Section 2.

---

## 4. Methodology

**(NSF: this is the bulk of the 15-page Project Description, 6-8 pages.
ERC B2: Section b, 7-10 pages.)**

### 4.1 Approach

{{Technical narrative organized by objective. Pseudo-code or formulas where
useful. Justify every non-trivial design choice against an alternative.}}

### 4.2 Preliminary Results / Proof of Concept

{{If available, include 1-2 preliminary figures or tables. Even informal
results strengthen feasibility.}}

### 4.3 Work Packages (optional; strongly recommended for ERC)

| WP | Title | Lead | Duration | Deliverables | Dependencies |
|----|-------|------|----------|--------------|--------------|
| WP1 | {{...}} | {{PI}} | M1-M12 | {{D1.1, D1.2}} | - |
| WP2 | {{...}} | {{postdoc}} | M9-M24 | {{D2.1}} | WP1 |

### 4.4 Risks and Contingency Plans

**(ERC B2: required.) (NSF: strongly encouraged.)**

| Risk | Likelihood | Impact | Mitigation / Alternative |
|------|-----------|--------|--------------------------|
| {{dataset unavailable}} | M | H | {{fallback dataset X, Y}} |
| {{compute constraint}} | L | M | {{parameter-efficient alternative}} |
| {{novelty collision}} | L | H | {{differentiation strategy}} |

---

## 5. Timeline

Year-by-year or milestone-driven Gantt-style view.

```
Month:        M01  M06  M12  M18  M24  M30  M36
WP1           |=============|
WP2                  |==============|
WP3                       |===================|
Dissemination              |======================|
```

Major deliverables and milestones listed by month.

---

## 6. Expected Outcomes and Impact

- **Scientific impact**: {{how the field advances}}.
- **Technical artifacts**: {{open-source release, dataset, benchmark}}.
- **Dissemination plan**: {{target venues for publication, planned timeline}}.
- **Broader Impacts** (NSF, expand on Section 1): {{education, outreach,
  diversity, industry transfer}}.

---

## 7. Results from Prior {{Scheme}} Support (renewal only)

**(NSF: mandatory for renewals; <= 5 pages. Must use the two headings
"Intellectual Merit" and "Broader Impacts" exactly.)**

### Award: {{number}}, {{period}}, {{amount}}

**Intellectual Merit**: {{summary of knowledge advances}}.

**Broader Impacts**: {{summary of societal / educational outcomes}}.

Selected publications: {{cite 3-5 outputs}}.

---

## 8. References

{{Generated from `$LITREV_WORKDIR/bibliography.bib`. NSF: References Cited
is a separate document (no page limit). ERC: references count separately
from the 14-page limit.}}

<!-- BIBTEX_PLACEHOLDER -->

---

## Rendering rules (for the orchestrator)

1. Fill placeholders `{{VAR}}` from `scope.json`, `matrix.jsonl`,
   `related_work.md`.
2. For NSF target: strip ALL URLs from the filled document before output
   (use BibTeX keys instead). URLs are prohibited in the Project Description.
3. For ERC target: flag any Section 2 subsection that does NOT contain the
   phrase "gap" or "insufficient" or equivalent critique language and ask
   the user to rewrite. ERC rejects descriptive State-of-the-Art.
4. Page-count discipline:
   - NSF: total Project Description <= 15 pages (including figures).
   - ERC B1: <= 5 pages. Use only Sections 1, 2 (short), 3, 4.1, 6.
   - ERC B2: <= 14 pages. Use all sections.
5. The "Results from Prior Support" heading text MUST be exact for NSF:
   "Intellectual Merit" and "Broader Impacts" literal headings.
6. Never invent results or prior work. If a claim has no matrix support,
   write `?` and ask the user.
