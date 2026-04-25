<!--
Template consumed by the literature-review skill at Phase 6.
The orchestrator fills placeholders with shortlist data + section_splitter output.
Organize papers into 2-4 thematic clusters. Each paragraph weaves 2-5 citations.
-->

# Related Work (draft)

Topic: {{TOPIC}}
Papers cited: {{N_PAPERS}}
Generated: {{DATE}}

---

## {{theme_1_name}}

{{theme_1_framing}}

{{cite[A]}} introduced {{contribution_A}}, achieving {{headline_A}} on {{dataset_A}}. Building on this, {{cite[B]}} addressed {{limitation_of_A}} by {{contribution_B}}. However, both approaches assume {{shared_assumption}}, which leaves open {{open_problem}}.

{{cite[C]}}, {{cite[D]}}, and {{cite[E]}} pursue a complementary direction of {{alt_direction}}. Among these, {{cite[C]}} reports the strongest results on {{metric}}, but requires {{tradeoff_C}}.

## {{theme_2_name}}

{{theme_2_framing}}

A parallel line of work focuses on {{theme_2_focus}}. {{cite[F]}} proposed {{contribution_F}}; {{cite[G]}} extended this with {{contribution_G}}. {{cite[H]}} reported {{negative_finding_H}}, which motivates {{followup}}.

## Positioning of Our Work

<!-- Optional: if user has stated their own contribution at Phase 0, render this section. -->

Our contribution differs from the above in three ways:

1. {{diff_1}} (whereas {{cite[A]}}, {{cite[B]}} assume {{their_assumption}}).
2. {{diff_2}} (whereas {{cite[C]}} requires {{their_requirement}}).
3. {{diff_3}}.

---

## Citation Keys

<!-- Ordered list by first appearance in the text above. Matches BibTeX keys in bibliography.bib. -->

- A = {{bibkey_A}}   {{zotero_item_url_A}}
- B = {{bibkey_B}}   {{zotero_item_url_B}}
- C = {{bibkey_C}}   {{zotero_item_url_C}}
- D = {{bibkey_D}}   {{zotero_item_url_D}}
- E = {{bibkey_E}}   {{zotero_item_url_E}}
- F = {{bibkey_F}}   {{zotero_item_url_F}}
- G = {{bibkey_G}}   {{zotero_item_url_G}}
- H = {{bibkey_H}}   {{zotero_item_url_H}}

## Rendering rules (for the orchestrator)

1. Cluster papers by shared technique / problem framing, NOT by chronology.
2. Every claim about a paper must trace to its `row.json` or `sections.json` under `$LITREV_WORKDIR/papers/`.
3. Prefer present tense for the cited work and active voice.
4. Use `\\cite{key}` style placeholders if the user plans LaTeX; use `[Author, Year]` if rendering Markdown.
5. Keep each paragraph to 3-5 sentences. Do NOT summarize abstracts verbatim.
6. If the "Positioning of Our Work" section has no user-stated contribution, omit it entirely rather than filling with platitudes.
