#!/usr/bin/env python3
"""
section_splitter.py - Split academic HTML into canonical sections.

Input:  HTML file path (or stdin via "-")
Output: JSON with canonical section buckets.

Canonical buckets (heading keyword -> bucket):
    introduction     "introduc", "overview"
    related_work     "related work", "background", "prior work", "literature"
    method           "method", "approach", "model", "architecture", "algorithm", "propose"
    experiments      "experiment", "setup", "implementation", "benchmark"
    results          "result", "evaluation", "analysis", "ablat"
    discussion       "discussion", "discuss"
    limitations      "limitation", "future work", "broader impact"
    conclusion       "conclusion", "concluding"
    other            headings that do not match any bucket

arXiv ar5iv HTML is detected via `ltx_section` class and parsed preferentially.
Generic HTML falls back to h1/h2 heading boundaries.

Math tags are replaced with $LaTeX$ when an `alttext` attribute is available,
otherwise with the literal token [MATH].

Usage:
    python arxiv_fetch.py html 2401.12345 | python section_splitter.py - > sections.json
    python section_splitter.py paper.html > sections.json

Output JSON shape:
{
  "title": "...",
  "abstract": "...",
  "sections": {
    "introduction": "...",
    "related_work": "...",
    "method": "...",
    "experiments": "...",
    "results": "...",
    "discussion": "...",
    "limitations": "...",
    "conclusion": "...",
    "other": [{"heading": "...", "body": "..."}, ...]
  }
}
"""
import html as html_lib
import json
import re
import sys


SECTION_CATEGORIES = [
    ("introduction", [r"introduc", r"overview"]),
    ("related_work", [r"related work", r"background", r"prior work", r"literature"]),
    ("method", [r"method", r"approach", r"model", r"architecture", r"algorithm", r"propose"]),
    ("experiments", [r"experiment", r"setup", r"implementation", r"benchmark"]),
    ("results", [r"result", r"evaluation", r"analysis", r"ablat"]),
    ("discussion", [r"discussion", r"discuss"]),
    ("limitations", [r"limitation", r"future work", r"broader impact"]),
    ("conclusion", [r"conclusion", r"concluding"]),
]

ARXIV_SECTION_RE = re.compile(
    r'<section[^>]*class="[^"]*ltx_section[^"]*"[^>]*>(.*?)</section>',
    re.S | re.I,
)
ARXIV_TITLE_RE = re.compile(
    r'<h[1-3][^>]*class="[^"]*ltx_title[^"]*"[^>]*>(.*?)</h[1-3]>',
    re.S | re.I,
)
ARXIV_ABSTRACT_RE = re.compile(
    r'<div[^>]*class="[^"]*ltx_abstract[^"]*"[^>]*>(.*?)</div>',
    re.S | re.I,
)
DOC_TITLE_RE = re.compile(
    r'<h1[^>]*class="[^"]*ltx_title_document[^"]*"[^>]*>(.*?)</h1>',
    re.S | re.I,
)
GENERIC_TITLE_RE = re.compile(r'<title[^>]*>(.*?)</title>', re.S | re.I)
GENERIC_H_RE = re.compile(r'<(h[12])[^>]*>(.*?)</h[12]>', re.S | re.I)


def _math_to_latex(match):
    math_html = match.group(0)
    m = re.search(r'alttext="([^"]+)"', math_html)
    if m:
        return f" ${html_lib.unescape(m.group(1))}$ "
    return " [MATH] "


def _strip_tags(s):
    s = re.sub(r"<script[^>]*>.*?</script>", "", s, flags=re.S | re.I)
    s = re.sub(r"<style[^>]*>.*?</style>", "", s, flags=re.S | re.I)
    s = re.sub(r"<math[^>]*?>.*?</math>", _math_to_latex, s, flags=re.S | re.I)
    s = re.sub(r"<[^>]+>", " ", s)
    s = html_lib.unescape(s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def _classify(heading):
    h = heading.lower().strip()
    h = re.sub(r"^\d+(\.\d+)*\.?\s*", "", h)
    # Roman-numeral prefix must end with ". " or it would swallow the "i" of "introduction".
    h = re.sub(r"^[ivxlcdm]{1,5}\.\s+", "", h, flags=re.I)
    for cat, patterns in SECTION_CATEGORIES:
        for p in patterns:
            if re.search(p, h):
                return cat
    return None


def _new_result():
    r = {
        "title": "",
        "abstract": "",
        "sections": {cat: "" for cat, _ in SECTION_CATEGORIES},
    }
    r["sections"]["other"] = []
    return r


def _assign(result, cat, text, heading=""):
    if cat and cat in result["sections"]:
        if result["sections"][cat]:
            result["sections"][cat] += "\n\n" + text
        else:
            result["sections"][cat] = text
    else:
        result["sections"]["other"].append({"heading": heading, "body": text})


def split_arxiv(html):
    result = _new_result()

    m = DOC_TITLE_RE.search(html)
    if m:
        result["title"] = _strip_tags(m.group(1))
    else:
        m = GENERIC_TITLE_RE.search(html)
        if m:
            result["title"] = _strip_tags(m.group(1))

    m = ARXIV_ABSTRACT_RE.search(html)
    if m:
        result["abstract"] = _strip_tags(m.group(1))

    for sec in ARXIV_SECTION_RE.finditer(html):
        body = sec.group(1)
        tm = ARXIV_TITLE_RE.search(body)
        heading = _strip_tags(tm.group(1)) if tm else ""
        text = _strip_tags(body)
        cat = _classify(heading)
        _assign(result, cat, text, heading=heading)

    return result


def split_generic(html):
    result = _new_result()

    m = GENERIC_TITLE_RE.search(html)
    if m:
        result["title"] = _strip_tags(m.group(1))

    chunks = []
    last_heading = None
    last_end = 0
    for m in GENERIC_H_RE.finditer(html):
        if last_heading is not None:
            chunks.append((last_heading, html[last_end:m.start()]))
        last_heading = _strip_tags(m.group(2))
        last_end = m.end()
    if last_heading is not None:
        chunks.append((last_heading, html[last_end:]))

    for heading, body in chunks:
        text = _strip_tags(body)
        if not result["abstract"] and re.match(r"^abstract$", heading.strip().lower()):
            result["abstract"] = text
            continue
        cat = _classify(heading)
        _assign(result, cat, text, heading=heading)

    return result


def split(html):
    if re.search(r'class="[^"]*ltx_section', html, re.I):
        return split_arxiv(html)
    return split_generic(html)


def main():
    if len(sys.argv) > 1 and sys.argv[1] != "-":
        with open(sys.argv[1], "r", encoding="utf-8") as f:
            html = f.read()
    else:
        html = sys.stdin.read()
    out = split(html)
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
