#!/usr/bin/env python3
"""
Minimal translation script: CN -> EN, EN -> CN.
Author: ChatGPT

Requirements:
- Python 3.7+
- OPENAI_API_KEY must be set in environment variables.

No external dependencies are needed; it only relies on the standard library.
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request

# API_URL = "https://api.openai.com/v1/chat/completions"
# MODEL = "gpt-4o-mini"  # or any other chat-capable model you have access to
# API_KEY = os.getenv("OPENAI_API_KEY")
API_URL = "https://api.deepseek.com/chat/completions"
MODEL = "deepseek-chat"  # or any other chat-capable model you have access to
API_KEY = os.getenv("DEEPSEEK_API_KEY")

if not API_KEY:
    sys.exit("Error: OPENAI_API_KEY environment variable not set.")


def is_chinese(text: str) -> bool:
    """Return True if the string contains any CJK Unified Ideographs."""
    return bool(re.search(r"[\u4e00-\u9fff]", text))


def build_payload(text: str) -> bytes:
    """Create the JSON payload for the chat completion request."""
    if is_chinese(text):
        system_prompt = "You are a translator. Translate the user text from Chinese to English, directly output the translated text without any additional text."
    else:
        system_prompt = "You are a translator. Translate the user text from English to Chinese, directly output the translated text without any additional text."

    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text}
        ],
        "temperature": 0.3
    }
    return json.dumps(payload).encode("utf-8")


def translate(text: str) -> str:
    """Send the request and return the translated text."""
    request = urllib.request.Request(
        API_URL,
        data=build_payload(text),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {API_KEY}"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(request) as response:
            resp_json = json.loads(response.read())
    except urllib.error.HTTPError as e:
        error_detail = e.read().decode()
        raise RuntimeError(f"HTTP {e.code}: {error_detail}") from None

    try:
        return resp_json["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError):
        raise RuntimeError(f"Unexpected response format: {resp_json}") from None


def main() -> None:
    if len(sys.argv) > 1:
        src = " ".join(sys.argv[1:])
        try:
            result = translate(src)
            print(result)
        except Exception as exc:
            print(f"Error: {exc}", file=sys.stderr)
    else:
        print("Enter text to translate (Ctrl+D / Ctrl+Z to exit):")
        for line in sys.stdin:
            src = line.rstrip("\n")
            if not src:
                continue
            try:
                result = translate(src)
                print("▼ Translation ▼")
                print(result)
                print("▲ End ▲\n")
            except Exception as exc:
                print(f"Error: {exc}", file=sys.stderr)


if __name__ == "__main__":
    main()

