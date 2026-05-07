# Paywall Fallback (Stage C)

Trigger: `pdf_fetch.py` exits 3 with `status: paywalled` in its manifest. The
Stage A/B chain (arxiv -> direct pdf_url -> Unpaywall) failed for a paper the
main agent has decided is worth deep reading.

Stage C has two sub-modes:

- **Mode A: agent-driven (`prepare`)** - the agent uses chrome-devtools MCP
  to follow a publisher-specific strategy (IEEE / ACM / Springer / ...).
  Pure automation, no human in the loop. See "Per-publisher strategy" below.
- **Mode B: user-driven (`prepare --user-mode`)** - the agent hands off
  navigation to the user, who downloads the PDF in a real browser
  (chrome-devtools window or their own Chrome). Used when Mode A is
  unsuitable (login wall, captcha, unknown publisher, repeated failure,
  or non-DOI landing pages). See "User-driven Fallback (Mode B)" below.

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

## User-driven Fallback (Mode B)

When Mode A is the wrong tool (login wall, captcha, unknown publisher, two
strategy attempts already failed, or no DOI exists at all), hand off to the
human. The agent stops automating clicks and instead opens a browser the user
can drive.

### When to invoke Mode B

Trigger Mode B when ANY of:

- `paywall_browser.py prepare` (default mode) emits `publisher: unknown`
  / `strategy: generic` (it will print a stderr hint suggesting `--user-mode`).
- Mode A automated attempts fail twice on the same paper (hard limit per
  "Failure handling" below).
- Landing page presents a login form, captcha, cookie consent banner, or
  similar interactive gate that is awkward to script and the user has
  institutional access.
- Manifest has no DOI but does have `input_meta.url` pointing at an
  open-access PDF behind a paywall-shaped landing page (preprint server,
  workshop site, dataset webpage).
- User explicitly requests manual handoff.

### Flow

```
pdf_fetch.py status=paywalled
    |
    v
paywall_browser.py prepare --user-mode --manifest papers/<id>/manifest.json
    - emits a recipe with strategy="user-driven" and a user_instructions list
    - hint points the agent at chrome-devtools navigation
    |
    v
Main agent reads recipe and:
    1. mcp_chrome-devtools_new_page(url=recipe.landing_url)
       (creates a Chrome window the user can see and click in)
    2. mcp_Question to the user, e.g.:
       "I opened the publisher landing page. Please:
        - log in / accept cookies / solve captcha if asked
        - find the PDF download link and save the file to:
          <recipe.expected_output>
        Or, open <recipe.landing_url> in your own browser instead.
        Reply 'done' when the PDF is at the expected path,
        or 'skip' to abandon this paper."
    3. wait for user reply (the agent's turn ends; user response wakes it).
    |
    v
Main agent verifies:
    - reply='skip' -> record status=user_skipped in manifest, continue.
    - reply='done' -> stat the expected_output:
        if file exists and starts with %PDF -> next step
        else mcp_Question again ("file missing or not a PDF, retry or skip?")
    |
    v
paywall_browser.py verify --manifest <...> --pdf <expected_output> \
                          --source user-driven
    - confirms PDF magic bytes + size sanity check
    - writes manifest.status=ok, manifest.source=user-driven
    |
    v
Phase 4 deep-read resumes (MinerU, section split, row.json, Zotero import)
```

### Hard rules (Mode B)

Same do-no-harm constraints as Mode A, plus:

- Maximum ONE user-driven attempt per paper per session. If the user replies
  'skip' or the file does not appear, mark `status=user_skipped` and move on.
  Do not re-prompt within the same session.
- Never auto-fill credentials in the chrome-devtools session on behalf of the
  user. The user enters their own credentials, or declines.
- Do not exfiltrate or persist any login form contents from the
  chrome-devtools session beyond what the user explicitly asks (e.g. saving
  the downloaded PDF). Cookies remain in the MCP session and are not
  serialized to disk.
- The agent's `mcp_Question` MUST surface the exact `expected_output` path so
  the user can save the PDF without ambiguity. Relative paths are forbidden.

### When Mode B is preferred over Mode A from the start

For these publishers, default to Mode B without trying Mode A:

- Elsevier / ScienceDirect (`10.1016/...`): Mode A almost always lands on a
  consent dialog the agent cannot reliably dismiss; user-driven is faster.
- Wiley (`10.1002/...`) for non-OA papers: same rationale.
- Personal author pages, institutional repositories, workshop PDFs hosted
  outside the major publishers: Mode A's `PUBLISHER_MAP` has no entry, so
  Mode B is the natural path.

For IEEE / ACM / Springer Mode A is still preferred (they have stable URL
patterns); fall back to Mode B only on Mode A failure.

## Failure handling

| Failure | Action |
|---------|--------|
| Landing page returns 404 / deleted DOI | Record in session_log, status=doi_dead, continue |
| Publisher requires institution login we do not have | Switch to Mode B (user-driven) and let the user log in; if user skips, record status=paywalled_no_access |
| PDF download starts but file is corrupted / non-PDF | Retry once; if still bad, switch to Mode B; if Mode B also fails, record status=paywall_failed |
| chrome-devtools MCP unavailable on this host | Skip Mode A. Mode B can still work via "open this URL in your own browser" prompt - the agent does not strictly need chrome-devtools to drive a user-driven flow. |
| Sci-Hub / mirror policy requires explicit user consent | Do NOT auto-scrape; require user opt-in flag `--allow-mirrors` |

**Hard rule:** never attempt >= 3 paywall bypasses on the same paper in one
session. Mode A: two strategy attempts max. Mode B: one user-driven attempt
max. Total Stage C attempts per paper <= 3. Stage C must not loop.

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
