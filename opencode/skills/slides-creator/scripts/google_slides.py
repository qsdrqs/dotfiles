#!/usr/bin/env python3
"""
Google Slides helper for the slides-creator skill.

This script intentionally imports only Python stdlib at module load time.
Google client libraries are imported lazily by commands that need them.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import venv
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, NoReturn, Sequence


DEFAULT_VENV = Path('/tmp/slides-creator-google-slides-venv')
DEFAULT_CREDENTIALS = Path('credentials.json')
DEFAULT_TOKEN = Path('token.json')
SLIDES_SCOPE = 'https://www.googleapis.com/auth/presentations'
READONLY_SCOPE = 'https://www.googleapis.com/auth/presentations.readonly'
DEFAULT_SLIDE_HEIGHT_PT = 405
REQUIRED_PACKAGES = (
    'google-api-python-client',
    'google-auth-httplib2',
    'google-auth-oauthlib',
)


@dataclass(frozen=True)
class ImageSpec:
    alt: str
    url: str


@dataclass(frozen=True)
class MarkdownSlide:
    title: str
    bullets: list[str]
    images: list[ImageSpec] = field(default_factory=list)


def die(message: str, code: int = 1) -> NoReturn:
    print(f'Error: {message}', file=sys.stderr)
    raise SystemExit(code)


def info(message: str) -> None:
    print(message, file=sys.stderr)


def extract_presentation_id(value: str) -> str:
    value = value.strip()
    match = re.search(r'/presentation/d/([^/]+)', value)
    if match:
        return match.group(1)
    if value:
        return value
    die('presentation ID or URL is empty')


def parse_markdown_deck(text: str) -> list[MarkdownSlide]:
    chunks = re.split(r'^---\s*$', text, flags=re.MULTILINE)
    slides: list[MarkdownSlide] = []
    for chunk in chunks:
        lines = [line.rstrip() for line in chunk.strip().splitlines() if line.strip()]
        if not lines:
            continue

        title = 'Untitled'
        body_start = 0
        first = lines[0].strip()
        if first.startswith('#'):
            title = first.lstrip('#').strip() or 'Untitled'
            body_start = 1

        bullets: list[str] = []
        images: list[ImageSpec] = []
        for raw in lines[body_start:]:
            leading = len(raw) - len(raw.lstrip(' '))
            stripped = raw.strip()
            image_match = re.fullmatch(r'!\[([^\]]*)\]\(([^)]+)\)', stripped)
            if image_match:
                images.append(ImageSpec(alt=image_match.group(1).strip(), url=image_match.group(2).strip()))
            elif stripped.startswith('- '):
                bullets.append((' ' * leading) + stripped[2:].strip())
            else:
                bullets.append((' ' * leading) + stripped)
        slides.append(MarkdownSlide(title=title, bullets=bullets, images=images))
    return slides


def load_markdown_deck(path: Path) -> list[MarkdownSlide]:
    try:
        text = path.read_text(encoding='utf-8')
    except OSError as exc:
        die(f'cannot read Markdown deck {path}: {exc}')
    slides = parse_markdown_deck(text)
    if not slides:
        die(f'no slides found in {path}')
    return slides


def self_test() -> None:
    pid = extract_presentation_id('https://docs.google.com/presentation/d/abc123_DEF-456/edit#slide=id.g1')
    assert pid == 'abc123_DEF-456', pid
    slides = parse_markdown_deck('''
# Title One
- Point A
  - Detail A1
---
# Title Two
- Point B
''')
    assert len(slides) == 2, slides
    assert slides[0].title == 'Title One', slides[0]
    assert slides[0].bullets == ['Point A', '  Detail A1'], slides[0].bullets
    assert slides[1].title == 'Title Two', slides[1]
    figure = parse_markdown_deck('''
# Figure
![Alt text](https://example.com/image.png)
- Caption
''')
    assert figure[0].images == [ImageSpec(alt='Alt text', url='https://example.com/image.png')], figure[0].images
    print('self-test passed')


def pt(value: float) -> dict[str, Any]:
    return {'magnitude': value, 'unit': 'PT'}


def size(width: float, height: float) -> dict[str, Any]:
    return {'width': pt(width), 'height': pt(height)}


def transform(x: float, y: float) -> dict[str, Any]:
    return {'scaleX': 1, 'scaleY': 1, 'translateX': x, 'translateY': y, 'unit': 'PT'}


def safe_object_id(prefix: str, index: int) -> str:
    return f'{prefix}_{index:03d}'


def placeholder_mapping(placeholder_type: str, object_id: str) -> dict[str, Any]:
    return {
        'layoutPlaceholder': {'type': placeholder_type, 'index': 0},
        'objectId': object_id,
    }


def insert_text_request(object_id: str, text: str) -> dict[str, Any]:
    return {'insertText': {'objectId': object_id, 'text': text, 'insertionIndex': 0}}


def create_paragraph_bullets_request(object_id: str) -> dict[str, Any]:
    return {
        'createParagraphBullets': {
            'objectId': object_id,
            'textRange': {'type': 'ALL'},
            'bulletPreset': 'BULLET_DISC_CIRCLE_SQUARE',
        }
    }


def bullets_to_slides_text(bullets: Sequence[str]) -> str:
    lines: list[str] = []
    for bullet in bullets:
        leading = len(bullet) - len(bullet.lstrip(' '))
        content = bullet.lstrip(' ')
        lines.append(('\t' * (leading // 2)) + content)
    return '\n'.join(lines)


def create_layout_slide_request(
    slide_id: str,
    predefined_layout: str,
    mappings: Sequence[dict[str, Any]],
) -> dict[str, Any]:
    request: dict[str, Any] = {
        'createSlide': {
            'objectId': slide_id,
            'slideLayoutReference': {'predefinedLayout': predefined_layout},
        }
    }
    if mappings:
        request['createSlide']['placeholderIdMappings'] = list(mappings)
    return request


def title_slide_requests(slide: MarkdownSlide, index: int) -> list[dict[str, Any]]:
    slide_id = safe_object_id('slide', index)
    title_id = safe_object_id('title', index)
    subtitle_id = safe_object_id('subtitle', index)
    subtitle = '\n'.join(slide.bullets)
    requests = [
        create_layout_slide_request(
            slide_id,
            'TITLE',
            [
                placeholder_mapping('CENTERED_TITLE', title_id),
                placeholder_mapping('SUBTITLE', subtitle_id),
            ],
        ),
        insert_text_request(title_id, slide.title),
    ]
    if subtitle:
        requests.append(insert_text_request(subtitle_id, subtitle))
    return requests


def body_slide_requests(slide: MarkdownSlide, index: int) -> list[dict[str, Any]]:
    slide_id = safe_object_id('slide', index)
    title_id = safe_object_id('title', index)
    body_id = safe_object_id('body', index)
    body_text = bullets_to_slides_text(slide.bullets) if slide.bullets else ''
    requests: list[dict[str, Any]] = [
        create_layout_slide_request(
            slide_id,
            'TITLE_AND_BODY',
            [
                placeholder_mapping('TITLE', title_id),
                placeholder_mapping('BODY', body_id),
            ],
        ),
        insert_text_request(title_id, slide.title),
    ]
    if body_text:
        requests.append(insert_text_request(body_id, body_text))
        requests.append(create_paragraph_bullets_request(body_id))
    return requests


def figure_slide_requests(slide: MarkdownSlide, index: int) -> list[dict[str, Any]]:
    slide_id = safe_object_id('slide', index)
    title_id = safe_object_id('title', index)
    image_id = safe_object_id('image', index)
    caption_id = safe_object_id('caption', index)
    image = slide.images[0]
    caption = '\n'.join(slide.bullets) or image.alt
    requests: list[dict[str, Any]] = [
        create_layout_slide_request(
            slide_id,
            'TITLE_ONLY',
            [placeholder_mapping('TITLE', title_id)],
        ),
        insert_text_request(title_id, slide.title),
        {
            'createImage': {
                'objectId': image_id,
                'url': image.url,
                'elementProperties': {
                    'pageObjectId': slide_id,
                    'size': size(440, 220),
                    'transform': transform(140, 120),
                },
            }
        },
    ]
    if caption:
        requests.extend([
            {
                'createShape': {
                    'objectId': caption_id,
                    'shapeType': 'TEXT_BOX',
                    'elementProperties': {
                        'pageObjectId': slide_id,
                        'size': size(440, 30),
                        'transform': transform(140, DEFAULT_SLIDE_HEIGHT_PT - 45),
                    },
                }
            },
            insert_text_request(caption_id, caption),
        ])
    return requests


def slide_requests(slide: MarkdownSlide, index: int) -> list[dict[str, Any]]:
    if index == 1:
        return title_slide_requests(slide, index)
    if slide.images:
        return figure_slide_requests(slide, index)
    return body_slide_requests(slide, index)


def build_markdown_requests(slides: Sequence[MarkdownSlide]) -> list[dict[str, Any]]:
    requests: list[dict[str, Any]] = []
    for i, slide in enumerate(slides, start=1):
        requests.extend(slide_requests(slide, i))
    return requests


def find_slide_id_by_index(presentation: dict[str, Any], slide_index: int) -> str:
    slides = presentation.get('slides', [])
    if slide_index < 1 or slide_index > len(slides):
        die(f'slide index {slide_index} outside range 1..{len(slides)}')
    return slides[slide_index - 1].get('objectId', '')


def cmd_self_test(args: argparse.Namespace) -> None:
    self_test()


def run_command(command: Sequence[str]) -> None:
    info('+ ' + ' '.join(command))
    try:
        subprocess.run(command, check=True, stdout=sys.stderr, stderr=sys.stderr)
    except FileNotFoundError as exc:
        die(f'command not found: {exc.filename}')
    except subprocess.CalledProcessError as exc:
        die(f'command failed with exit code {exc.returncode}: {command}')


def dependency_hint() -> str:
    return (
        'Google client libraries are missing. Run '
        '`python3 opencode/skills/slides-creator/scripts/google_slides.py bootstrap-venv`, '
        'then rerun this command with '
        '`/tmp/slides-creator-google-slides-venv/bin/python`.'
    )


def load_google_modules() -> dict[str, Any]:
    try:
        from google.auth.transport.requests import Request  # pyright: ignore[reportMissingImports]
        from google.oauth2.credentials import Credentials  # pyright: ignore[reportMissingImports]
        from google_auth_oauthlib.flow import InstalledAppFlow  # pyright: ignore[reportMissingImports]
        from googleapiclient.discovery import build  # pyright: ignore[reportMissingImports]
        from googleapiclient.errors import HttpError  # pyright: ignore[reportMissingImports]
    except ImportError as exc:
        die(f'{exc}. {dependency_hint()}')
    return {
        'Request': Request,
        'Credentials': Credentials,
        'InstalledAppFlow': InstalledAppFlow,
        'build': build,
        'HttpError': HttpError,
    }


def resolve_path(value: str | None, default: Path) -> Path:
    if value:
        return Path(value).expanduser()
    return default


def scope_set_covers(granted_scopes: Iterable[str], requested_scopes: Sequence[str]) -> bool:
    granted = set(granted_scopes)
    requested = set(requested_scopes)
    if SLIDES_SCOPE in granted:
        requested.discard(READONLY_SCOPE)
    return requested.issubset(granted)


def has_required_scopes(creds: Any, scopes: Sequence[str]) -> bool:
    granted_values = getattr(creds, 'granted_scopes', None) or getattr(creds, 'scopes', None)
    if granted_values:
        return scope_set_covers(granted_values, scopes)
    has_scopes = getattr(creds, 'has_scopes', None)
    if callable(has_scopes):
        return bool(has_scopes(scopes))
    return False


def write_token_file(path: Path, token_json: str) -> None:
    if path.exists():
        path.chmod(0o600)
    fd = os.open(str(path), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w', encoding='utf-8') as token_file:
        token_file.write(token_json)
    path.chmod(0o600)


def get_credentials(args: argparse.Namespace, scopes: Sequence[str]) -> Any:
    modules = load_google_modules()
    Credentials = modules['Credentials']
    Request = modules['Request']
    InstalledAppFlow = modules['InstalledAppFlow']
    token_path = resolve_path(getattr(args, 'token', None), DEFAULT_TOKEN)
    credentials_path = resolve_path(getattr(args, 'credentials', None), DEFAULT_CREDENTIALS)

    creds = None
    if token_path.exists():
        creds = Credentials.from_authorized_user_file(str(token_path))
        if not has_required_scopes(creds, scopes):
            creds = None
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
    if not creds or not creds.valid:
        if not credentials_path.exists():
            die(f'credentials file not found: {credentials_path}')
        if getattr(args, 'no_browser', False):
            die('valid token is missing and --no-browser was set')
        flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), scopes)
        creds = flow.run_local_server(port=0)
        write_token_file(token_path, creds.to_json())
    return creds


def build_slides_service(args: argparse.Namespace, scopes: Sequence[str] = (SLIDES_SCOPE,)) -> Any:
    modules = load_google_modules()
    creds = get_credentials(args, scopes)
    return modules['build']('slides', 'v1', credentials=creds)


def cmd_bootstrap_venv(args: argparse.Namespace) -> None:
    venv_path = Path(args.venv).expanduser()
    if not venv_path.exists():
        info(f'creating venv: {venv_path}')
        venv.EnvBuilder(with_pip=True).create(venv_path)
    python = venv_path / 'bin' / 'python'
    if not python.exists():
        die(f'expected venv python not found: {python}')

    run_command([str(python), '-m', 'pip', 'install', '--upgrade', 'pip'])
    run_command([str(python), '-m', 'pip', 'install', *REQUIRED_PACKAGES])
    print(json.dumps({
        'venv': str(venv_path),
        'python': str(python),
        'packages': list(REQUIRED_PACKAGES),
    }, indent=2))


def cmd_auth_check(args: argparse.Namespace) -> None:
    build_slides_service(args, scopes=(SLIDES_SCOPE,))
    print(json.dumps({'ok': True}, indent=2))


def cmd_get(args: argparse.Namespace) -> None:
    service = build_slides_service(args, scopes=(READONLY_SCOPE,))
    presentation_id = extract_presentation_id(args.presentation_id)
    data = service.presentations().get(presentationId=presentation_id).execute()
    slides = data.get('slides', [])
    summary = {
        'presentationId': presentation_id,
        'title': data.get('title', ''),
        'slideCount': len(slides),
        'slides': [
            {
                'index': i + 1,
                'objectId': slide.get('objectId', ''),
                'pageElementCount': len(slide.get('pageElements', [])),
            }
            for i, slide in enumerate(slides)
        ],
    }
    print(json.dumps(summary, indent=2))


def extract_text_runs(presentation: dict[str, Any]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for slide_index, slide in enumerate(presentation.get('slides', []), start=1):
        slide_id = slide.get('objectId', '')
        for element in slide.get('pageElements', []):
            shape = element.get('shape', {})
            text = shape.get('text', {})
            runs: list[str] = []
            for item in text.get('textElements', []):
                content = item.get('textRun', {}).get('content')
                if content:
                    runs.append(content)
            if runs:
                out.append({
                    'slideIndex': slide_index,
                    'slideObjectId': slide_id,
                    'elementObjectId': element.get('objectId', ''),
                    'text': ''.join(runs).strip(),
                })
    return out


def cmd_read_text(args: argparse.Namespace) -> None:
    service = build_slides_service(args, scopes=(READONLY_SCOPE,))
    presentation_id = extract_presentation_id(args.presentation_id)
    data = service.presentations().get(presentationId=presentation_id).execute()
    print(json.dumps(extract_text_runs(data), indent=2))


def cmd_create(args: argparse.Namespace) -> None:
    service = build_slides_service(args)
    data = service.presentations().create(body={'title': args.title}).execute()
    print(json.dumps({
        'presentationId': data.get('presentationId'),
        'title': data.get('title'),
        'url': f"https://docs.google.com/presentation/d/{data.get('presentationId')}/edit",
    }, indent=2))


def cmd_from_markdown(args: argparse.Namespace) -> None:
    slides = load_markdown_deck(Path(args.markdown))
    requests = build_markdown_requests(slides)
    if args.dry_run:
        print(json.dumps({'title': args.title, 'slideCount': len(slides), 'requests': requests}, indent=2))
        return

    service = build_slides_service(args)
    presentation = service.presentations().create(body={'title': args.title}).execute()
    presentation_id = presentation['presentationId']
    for slide in presentation.get('slides', []):
        slide_id = slide.get('objectId')
        if slide_id:
            requests.append({'deleteObject': {'objectId': slide_id}})
    service.presentations().batchUpdate(
        presentationId=presentation_id,
        body={'requests': requests},
    ).execute()
    print(json.dumps({
        'presentationId': presentation_id,
        'title': args.title,
        'url': f'https://docs.google.com/presentation/d/{presentation_id}/edit',
        'slideCount': len(slides),
    }, indent=2))


def cmd_replace_text(args: argparse.Namespace) -> None:
    if args.slide is None and args.slide_id is None and not args.confirm_global:
        die('global replacement requires --confirm-global')
    service = build_slides_service(args)
    presentation_id = extract_presentation_id(args.presentation_id)
    page_object_ids: list[str] | None = None
    if args.slide is not None or args.slide_id is not None:
        if args.slide_id:
            page_object_ids = [args.slide_id]
        else:
            slide_value = args.slide
            assert slide_value is not None
            slide_index = int(slide_value)
            data = service.presentations().get(presentationId=presentation_id).execute()
            page_object_ids = [find_slide_id_by_index(data, slide_index)]
    request: dict[str, Any] = {
        'replaceAllText': {
            'containsText': {'text': args.find, 'matchCase': args.match_case},
            'replaceText': args.replace,
        }
    }
    if page_object_ids is not None:
        request['replaceAllText']['pageObjectIds'] = page_object_ids
    result = service.presentations().batchUpdate(
        presentationId=presentation_id,
        body={'requests': [request]},
    ).execute()
    print(json.dumps(result, indent=2))


def add_auth_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument('--credentials', default=None, help='OAuth Desktop app credentials JSON path')
    parser.add_argument('--token', default=None, help='OAuth token JSON path')
    parser.add_argument('--no-browser', action='store_true', help='fail instead of opening OAuth browser flow')


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description='Google Slides helper for slides-creator')
    sub = parser.add_subparsers(dest='command', required=True)

    self_test_parser = sub.add_parser('self-test', help='run local parser tests without Google API access')
    self_test_parser.set_defaults(func=cmd_self_test)

    bootstrap = sub.add_parser('bootstrap-venv', help='create /tmp venv and install Google client packages')
    bootstrap.add_argument('--venv', default=str(DEFAULT_VENV), help='venv path')
    bootstrap.set_defaults(func=cmd_bootstrap_venv)

    auth_check = sub.add_parser('auth-check', help='validate OAuth and Slides API access')
    add_auth_args(auth_check)
    auth_check.set_defaults(func=cmd_auth_check)

    get_parser = sub.add_parser('get', help='read presentation metadata')
    add_auth_args(get_parser)
    get_parser.add_argument('presentation_id')
    get_parser.set_defaults(func=cmd_get)

    read_text = sub.add_parser('read-text', help='read text from presentation')
    add_auth_args(read_text)
    read_text.add_argument('presentation_id')
    read_text.set_defaults(func=cmd_read_text)

    create = sub.add_parser('create', help='create a blank presentation')
    add_auth_args(create)
    create.add_argument('--title', required=True)
    create.set_defaults(func=cmd_create)

    from_md = sub.add_parser('from-markdown', help='create a Google Slides deck from Markdown')
    add_auth_args(from_md)
    from_md.add_argument('markdown')
    from_md.add_argument('--title', required=True)
    from_md.add_argument('--dry-run', action='store_true', help='print batchUpdate requests without API calls')
    from_md.set_defaults(func=cmd_from_markdown)

    replace = sub.add_parser('replace-text', help='replace text globally or on one slide')
    add_auth_args(replace)
    replace.add_argument('presentation_id')
    replace.add_argument('--find', required=True)
    replace.add_argument('--replace', required=True)
    replace_scope = replace.add_mutually_exclusive_group()
    replace_scope.add_argument('--slide', type=int, default=None, help='1-based slide index')
    replace_scope.add_argument('--slide-id', default=None, help='slide objectId')
    replace.add_argument('--match-case', action='store_true')
    replace.add_argument('--confirm-global', action='store_true', help='required for global replacement')
    replace.set_defaults(func=cmd_replace_text)

    return parser


def main(argv: Sequence[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)


if __name__ == '__main__':
    main()
