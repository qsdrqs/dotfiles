# Paywall Fallback (Stage C)

Trigger: `pdf_fetch.py` exits 3 with `status: paywalled` in its manifest. The
Stage A/B chain (arxiv -> direct pdf_url -> Unpaywall) failed for a paper the
main agent has decided is worth deep reading.

Stage C adds a **chrome-devtools MCP** fallback that drives a real Chrome
instance to exercise cookie / institutional / publisher-embargo workarounds.

## When to invoke

Only for papers that satisfy ALL:

- Phase 4 deep-read queue (triaged in, survived Phase 2/3).
- `pdf_fetch.py` returned `paywalled` (exit 3).
- DOI is set (publisher landing page exists).
- Paper is **not** on the triage batch itself (paywall work happens only for
  post-merge survivors; see `citation-chasing.md` Step 4).

Do NOT invoke for:

- Papers that Stage A triage already rejected.
- Candidates still in the Stage C batch-triage phase (abstracts suffice).
- Papers with `status: no_identifier` (we have nothing to navigate to).

## Why chrome-devtools MCP

We need a JavaScript-capable browser because publisher paywalls use:

- JS-rendered download buttons (ACM `content/doi/XX.XXXX/full.pdf` routes).
- Institution-access cookies set before download is unlocked.
- Sci-Hub / open-archive mirrors that redirect through script.
- Canary anti-scrape mitigations (simple curl returns 403; Chrome with a real
  UA + accepted cookies returns 200).

The chrome-devtools MCP is driven by the main agent (not a Python script)
because:

1. Only main agent has MCP tool access.
2. Session state (cookies, login) is sticky across calls in a page.
3. We need ad-hoc reasoning (detect login forms, click the right button) that
   is awkward to script.

Python `paywall_browser.py` (Stage C) is a thin helper that prepares the
navigation recipe and post-processes downloads; it does NOT itself drive
Chrome.

## Flow

```
pdf_fetch.py status=paywalled
    |
    v
paywall_browser.py prepare
    - reads manifest.json and paper meta
    - emits a "navigation recipe" JSON:
        {doi, landing_url, publisher, strategy, expected_download_pattern}
    |
    v
Main agent reads recipe, invokes chrome-devtools MCP:
    1. new_page (or navigate)            -> landing_url
    2. wait_for                          -> landing text / PDF link element
    3. evaluate_script                   -> extract direct PDF url
    4. navigate                          -> PDF url (or click download button)
    5. list_network_requests / pdf blob  -> capture the download
    6. browser saves to user's Downloads (configured) OR
       evaluate_script returns base64, agent writes it to PAPER_DIR/paper.pdf
    |
    v
paywall_browser.py verify
    - confirms PAPER_DIR/paper.pdf starts with %PDF-
    - rewrites manifest.json: status=ok, source=chrome-devtools, via=paywall
    |
    v
Phase 4 deep-read resumes (MinerU, section split, row.json, Zotero import)
```

## Per-publisher strategy

`paywall_browser.py` maps DOI prefix / URL host to a navigation strategy:

| Publisher | Host / DOI prefix | Strategy |
|-----------|-------------------|----------|
| IEEE Xplore | `ieeexplore.ieee.org`, DOI `10.1109` | Landing -> "Download PDF" button -> direct URL pattern `/stamp/stamp.jsp?arnumber=...` |
| ACM DL | `dl.acm.org`, DOI `10.1145` | Landing -> `/doi/pdf/<doi>` direct route |
| Springer | `link.springer.com`, DOI `10.1007` | Landing -> `/content/pdf/<doi>.pdf` |
| Elsevier | `sciencedirect.com`, DOI `10.1016` | Landing -> check for institutional redirect; if not OA, skip |
| Nature | `nature.com`, DOI `10.1038` | Check open-access badge; if not, skip |
| Wiley | `onlinelibrary.wiley.com`, DOI `10.1002` | Landing -> "Download PDF" modal -> direct link |
| Taylor & Francis | `tandfonline.com` | Landing -> `/doi/pdf/<doi>` with session cookie |
| Unknown | * | Generic strategy: look for `<a>` with `.pdf` href or "Download" text |

Each strategy is encoded in `paywall_browser.py` as a stub the main agent reads.
The main agent still does the actual click/evaluate; the script only names the
next action.

## Failure handling

| Failure | Action |
|---------|--------|
| Landing page returns 404 / deleted DOI | Record in session_log, status=doi_dead, continue |
| Publisher requires institution login we do not have | Record status=paywalled_no_access, continue |
| PDF download starts but file is corrupted / non-PDF | Retry once; if still bad, record status=paywall_failed |
| chrome-devtools MCP unavailable on this host | Skip Stage C paywall fallback entirely; log to user |
| Sci-Hub / mirror policy requires explicit user consent | Do NOT auto-scrape; require user opt-in flag `--allow-mirrors` |

**Hard rule:** never attempt >= 3 paywall bypasses on the same paper in one
session. Two strategy attempts max, then record and move on. Stage C must not
loop.

## Do-no-harm constraints

- Do not log in to paywalled services as the user unless explicitly told.
- Do not store download cookies outside the MCP session.
- Do not send >= 1 req / 5 s to the same publisher host.
- Do not mirror or cache downloaded PDFs outside `$LITREV_WORKDIR/papers/<id>/`.
- Never attempt bypass on a paper flagged `consent_required=false` in the
  user's scope.json.

## Session log format

Each paywall fallback attempt appends to `$LITREV_WORKDIR/session_log.md`:

```
## Paywall fallback: <paper_id>
- doi: 10.xxxx/...
- publisher: <name>
- strategy: <ieee|acm|...>
- attempts: <n>
- result: ok|paywalled_no_access|doi_dead|paywall_failed
- duration_sec: <n>
- evidence: network_requests.json saved to papers/<id>/paywall/
```

## Primary sources

- chrome-devtools MCP tool set: upstream Chrome DevTools Protocol wrapped as
  MCP (see OpenCode's chrome-devtools MCP catalog).
- Unpaywall policy on direct PDF links:
  https://unpaywall.org/faq (why some OA papers still fail direct download)
- Publisher-specific download routes: empirical; document per host as you
  observe new ones.
