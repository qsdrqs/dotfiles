# Google Slides Reference

Use this reference when `slides-creator` needs to create or edit Google Slides.

## Modes

- Markdown deck mode: draft `slides.md`, validate ASCII, then create a new Google Slides deck.
- Create mode: create a blank or Markdown-backed presentation in Google Slides.
- Direct edit mode: read an existing presentation and edit specific pages without a full Markdown draft.

## Safety policy

Safe without extra confirmation:

- `auth-check`
- `get`
- `read-text`
- `create`
- `from-markdown` when creating a new presentation
- `replace-text` scoped with `--slide` or `--slide-id`

Require explicit confirmation:

- Deleting slides
- Global text replacement with `--confirm-global`
- Raw `batchUpdate` requests
- Any write where the target scope is unclear

## Local venv setup

Do not run global `pip install`.

Bootstrap a temporary venv:

```bash
python3 opencode/skills/slides-creator/scripts/google_slides.py bootstrap-venv
```

Then run Google commands with:

```bash
/tmp/slides-creator-google-slides-venv/bin/python \
  opencode/skills/slides-creator/scripts/google_slides.py auth-check
```

The bootstrap command installs these packages into `/tmp/slides-creator-google-slides-venv`:

- `google-api-python-client`
- `google-auth-httplib2`
- `google-auth-oauthlib`

If the user chooses an existing project venv, activate it first and run the script with that venv's Python.

## OAuth Desktop app setup

1. Open Google Cloud Console.
2. Create or select a project.
3. Enable Google Slides API.
4. Configure OAuth consent screen if needed.
5. Create OAuth Client ID with type Desktop app.
6. Download the file as `credentials.json`.
7. Put `credentials.json` in the working directory or pass `--credentials PATH`.

Never ask the user to paste OAuth secrets into chat.

## ADC support

ADC is not supported by this helper in the first pass. Use OAuth Desktop app credentials with `credentials.json` or `--credentials PATH`.

## Commands

```bash
python3 opencode/skills/slides-creator/scripts/google_slides.py self-test
python3 opencode/skills/slides-creator/scripts/google_slides.py bootstrap-venv
/tmp/slides-creator-google-slides-venv/bin/python opencode/skills/slides-creator/scripts/google_slides.py auth-check
/tmp/slides-creator-google-slides-venv/bin/python opencode/skills/slides-creator/scripts/google_slides.py get PRESENTATION_ID
/tmp/slides-creator-google-slides-venv/bin/python opencode/skills/slides-creator/scripts/google_slides.py read-text PRESENTATION_ID
/tmp/slides-creator-google-slides-venv/bin/python opencode/skills/slides-creator/scripts/google_slides.py create --title "Deck title"
/tmp/slides-creator-google-slides-venv/bin/python opencode/skills/slides-creator/scripts/google_slides.py from-markdown slides.md --title "Deck title"
/tmp/slides-creator-google-slides-venv/bin/python opencode/skills/slides-creator/scripts/google_slides.py replace-text PRESENTATION_ID --find old --replace new --slide 3
```

## Presentation IDs

The script accepts a raw presentation ID or a URL like:

```text
https://docs.google.com/presentation/d/PRESENTATION_ID/edit
```

## Markdown layout mapping

`from-markdown` creates standard Google Slides layouts rather than all-custom blank slides:

- Slide 1: `TITLE` layout.
  - Heading maps to the centered title placeholder.
  - Bullet text maps to the subtitle placeholder.
- Non-image slides after slide 1: `TITLE_AND_BODY` layout.
  - Heading maps to the title placeholder.
  - Bullets map to the body placeholder and are converted with `createParagraphBullets`.
  - Markdown two-space nesting is converted to tab-based Slides nesting before bullet creation.
- Image slides after slide 1: `TITLE_ONLY` layout.
  - A full-line Markdown image creates the image element.
  - Bullets become a custom caption text box inside the slide bounds.

Markdown image syntax:

```md
# Example figure of yyy
![Optional alt text](https://example.com/public-image.png)
- Subcaption
```

Use public image URLs. Local image files, Drive uploads, charts, and speaker notes are not supported by this helper yet.

## Markdown conversion limits

- `---` separates slides.
- If the first nonblank line is a Markdown heading, it becomes the slide title; otherwise the title is `Untitled`.
- Bullets become standard Google Slides bullets in body placeholders.
- Nested bullets are preserved as Slides bullet nesting where possible.
- Only the first image on an image slide is inserted.
- Complex themes are out of scope for the first pass.
