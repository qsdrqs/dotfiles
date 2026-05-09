---
name: mineru-converter
description: "PDF to Markdown conversion using the MinerU GPU container. Extracts text, tables (HTML), formulas (LaTeX), and figures from PDFs. Use when asked to convert a PDF to structured Markdown, extract content from a paper PDF, or set up the MinerU extraction pipeline."
---

# MinerU Converter Skill

Convert PDFs to structured Markdown using the [MinerU](https://github.com/opendatalab/MinerU)
GPU container. Extracts text, tables (HTML), formulas (LaTeX), and figures.

## When to use

- "convert this PDF to markdown"
- "extract content from this paper PDF"
- "set up MinerU for PDF extraction"
- Any task that needs PDF -> structured Markdown

## Prerequisites (one-time)

```bash
export MINERU_SKILL_DIR="$HOME/.config/opencode/skills/mineru-converter"

# Build + start the MinerU container (GPU required or SKIP_MINERU=1)
bash "$MINERU_SKILL_DIR/scripts/setup_containers.sh"
```

Verify:

```bash
python "$MINERU_SKILL_DIR/scripts/mineru_client.py" health
# {"base_url": "http://localhost:8000", "reachable": true}
```

First request typically waits 30-90s while models load into GPU memory.

## Converting a PDF

```bash
python "$MINERU_SKILL_DIR/scripts/mineru_client.py" convert \
    --pdf paper.pdf \
    --out ./output/
```

Default output:
- `output/<name>.md` - Markdown with tables (HTML) and formulas (LaTeX)
- `output/images/` - extracted figures and charts
- `output/<name>_content_list.json` - structured content by reading order

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--backend` | `pipeline` | `pipeline` (accurate, broad), `hybrid-auto-engine`, `vlm-auto-engine` |
| `--lang` | `en` | OCR language: `en` (English), `ch` (Chinese+English) |
| `--start N` | 0 | Start page (0-indexed) |
| `--end N` | 99999 | End page |
| `--no-images` | false | Skip image extraction (switches to JSON mode, faster) |
| `--no-content-list` | false | Skip `_content_list.json` output |

### Environment

| Variable | Default | Description |
|----------|---------|-------------|
| `MINERU_URL` | `http://localhost:8000` | MinerU API base URL |
| `MINERU_BACKEND` | `pipeline` | Parsing backend |
| `MINERU_LANG` | `en` | OCR language hint |

## Tearing down

```bash
bash "$MINERU_SKILL_DIR/scripts/teardown_containers.sh"
```

## Performance

Typical extraction: 30-90s per 10-20 page paper on consumer GPU (RTX 3090/4090, `pipeline` backend).
One PDF at a time (GPU memory constraint).

## When NOT to use

- arXiv papers where HTML is available -> use `arxiv_fetch.py html` (faster, no GPU cost)
- Text-heavy papers where abstract is sufficient -> skip full extraction
- No GPU available and SKIP_MINERU=1 -> fall back to `pdftotext` for plain text

## Further reading

- `references/mineru-integration.md` - container setup, health probes, troubleshooting
