<!--
Template consumed by the literature-review skill at Phase 6 when the user
selected output_type = "survey" in Phase 0.

Structure follows the dominant pattern in top ML/NLP surveys (Yang et al.
"Diffusion Models: A Comprehensive Survey", Zhao et al. "A Survey of Large
Language Models"):

  1. Opening figure = TAXONOMY TREE (every paper in the survey maps to a leaf)
  2. Foundations section BEFORE the taxonomy body (shared vocabulary)
  3. Thematic organization (chronological only WITHIN subsections)
  4. Comparison / tradeoff table (connections with other methods)
  5. Applications section organized by domain
  6. Named open problems (falsifiable, not "more work needed")
  7. GitHub companion repo section

Stage C is required for surveys because it performs the 1-hop snowball
that brings in the foundational cited-by-everyone papers a broad keyword
search misses.
-->

# Survey: {{TOPIC}}

Authors: {{AUTHORS}}
Version: {{VERSION}} ({{DATE}})
Companion repository: {{GITHUB_URL}}

---

## Abstract

{{2-3 paragraphs: motivation, scope, organization preview, key take-aways.
End with a pointer to the taxonomy figure (Figure 1).}}

---

## 1. Introduction

### 1.1 Motivation

{{Why is this survey needed now? What recent developments prompted it?
What existing surveys exist, and what gap does this one fill?}}

### 1.2 Scope

- **Covered**: {{methodological axes included in this survey.}}
- **Excluded**: {{adjacent topics intentionally left out, with one-line
  reason each.}}
- **Time window**: {{year range}}.

### 1.3 Taxonomy Overview

![Figure 1: Taxonomy of {{TOPIC}}](figures/taxonomy.svg)

Figure 1 organizes the surveyed methods into {{N}} top-level categories:

- **Category A**: {{short descriptor}} - see Section 3.
- **Category B**: {{short descriptor}} - see Section 4.
- **Category C**: {{short descriptor}} - see Section 5.

Every paper in this survey maps to a leaf node. The mapping is listed in
the companion GitHub repository.

---

## 2. Foundations

{{Define the mathematical / conceptual vocabulary used by the rest of the
survey. Readers should be able to read any body section with only this as
prerequisite.}}

### 2.1 {{Core concept 1}}

### 2.2 {{Core concept 2}}

### 2.3 Notation

{{Table of symbols used throughout the survey.}}

---

## 3. Category A: {{descriptor}}

Introduce the category + its defining assumptions. Cite the seminal paper
that established it (use Stage C cores here).

### 3.1 {{Subcategory A1}}

{{Thematic paragraph weaving 3-5 citations. Use chronological order
WITHIN this subsection to show how ideas evolved. Highlight trade-offs.}}

### 3.2 {{Subcategory A2}}

### 3.3 Discussion

{{What all Category A methods share; where they differ from Categories B
and C. Pointer to comparison table in Section 6.}}

---

## 4. Category B: {{descriptor}}

<!-- Repeat structure of Section 3 for Category B. -->

---

## 5. Category C: {{descriptor}}

<!-- Repeat structure of Section 3 for Category C. -->

---

## 6. Connections and Comparisons

### 6.1 Comparison with Neighboring Paradigms

Table contrasting this survey's method families against adjacent paradigms.

| Method Family | Sample Quality | Controllability | Training Cost | Inference Cost | Data Requirement | Representative Work |
|---------------|---------------|-----------------|---------------|----------------|------------------|---------------------|
| {{Cat A}} | {{rating}} | {{rating}} | {{rating}} | {{rating}} | {{rating}} | {{cite}} |
| {{Cat B}} | {{rating}} | {{rating}} | {{rating}} | {{rating}} | {{rating}} | {{cite}} |
| {{Cat C}} | {{rating}} | {{rating}} | {{rating}} | {{rating}} | {{rating}} | {{cite}} |
| {{Adjacent}} | {{rating}} | {{rating}} | {{rating}} | {{rating}} | {{rating}} | {{cite}} |

Ratings: High / Med / Low or quantitative where the literature permits
a direct number. Populate from `$LITREV_WORKDIR/matrix.jsonl`.

### 6.2 When to use which?

{{Decision tree or short guidance paragraph for practitioners.}}

---

## 7. Applications

Organize by domain, not by method. Each subsection:
  - Task formulation in that domain.
  - Which method family wins (with citations).
  - Benchmark results (populate from matrix `result` column).

### 7.1 {{Application domain 1}}

### 7.2 {{Application domain 2}}

### 7.3 {{Application domain 3}}

---

## 8. Open Problems and Future Directions

**Named, falsifiable problems. Not "more work needed".**

### 8.1 {{Open problem 1}}

**Why it matters**: {{...}}
**What is missing from current work**: {{...}}
**Plausible attack**: {{...}}

### 8.2 {{Open problem 2}}

### 8.3 {{Open problem 3}}

Target 3-6 open problems. Each must be specific enough that a first-year
PhD student could turn it into a thesis topic.

---

## 9. Conclusion

{{Summary of the taxonomy in 2-3 sentences. Re-state the 2-3 most important
take-aways. Do NOT end with vague hopefulness; end with the top open problem.}}

---

## Papers

<!--
Living paper list. Update alongside the companion GitHub repository. One
bullet per paper, grouped by category.
-->

### Category A

- {{Cite Key}}: {{one-line contribution from matrix row}}
- ...

### Category B

- ...

### Category C

- ...

---

## References

{{Generated from `$LITREV_WORKDIR/bibliography.bib`.}}

<!-- BIBTEX_PLACEHOLDER -->

---

## Rendering rules (for the orchestrator)

1. The taxonomy in Section 1.3 is authored MANUALLY by the orchestrator after
   clustering matrix rows thematically. Do NOT auto-generate from keyword
   frequency.
2. Every leaf node in the taxonomy must have >= 2 papers in the matrix; else
   merge or drop the node.
3. Section 2 (Foundations) must introduce every symbol used later; check
   by scanning for undefined variables.
4. Section 6.1 table ratings must trace to matrix fields; `?` for unknown.
5. Section 8 (Open Problems) must contain 3-6 items; fewer = under-scoped,
   more = diffuse. Each item must be falsifiable.
6. Section 3-5 subsections should end with "Discussion" paragraphs that
   foreshadow Section 6 comparisons.
7. Chronological order is only allowed INSIDE a subsection. Top-level
   structure is thematic.
8. Never invent open problems; they must cite the limitation column of
   >= 2 matrix rows as evidence.
