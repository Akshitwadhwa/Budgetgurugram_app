from __future__ import annotations

import hashlib
import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from openai import OpenAI

from core.config import get_settings

log = logging.getLogger(__name__)
PROMPTS_DIR = Path(__file__).parent / "prompts"


@dataclass
class LlmResult:
    content: Any
    model: str
    prompt_version: str
    tokens_in: int
    tokens_out: int


class LlmError(RuntimeError):
    pass


def prompt_text(name: str) -> str:
    path = PROMPTS_DIR / name
    return path.read_text(encoding="utf-8")


def prompt_version(name: str) -> str:
    raw = prompt_text(name)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:12]


def _client() -> OpenAI:
    settings = get_settings()
    if not settings.openai_api_key:
        raise LlmError("OPENAI_API_KEY is not set")
    return OpenAI(api_key=settings.openai_api_key)


def complete_structured(
    *,
    prompt_name: str,
    model: str,
    user: str,
    schema: dict[str, Any],
    schema_name: str = "payload",
) -> LlmResult:
    """Single chokepoint for every OpenAI call that must return JSON."""
    client = _client()
    system = prompt_text(prompt_name)
    version = prompt_version(prompt_name)
    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            response_format={
                "type": "json_schema",
                "json_schema": {
                    "name": schema_name,
                    "strict": True,
                    "schema": schema,
                },
            },
        )
    except Exception as exc:
        raise LlmError(str(exc)) from exc

    choice = response.choices[0].message.content or "{}"
    usage = response.usage
    return LlmResult(
        content=json.loads(choice),
        model=model,
        prompt_version=version,
        tokens_in=usage.prompt_tokens if usage else 0,
        tokens_out=usage.completion_tokens if usage else 0,
    )


def complete_text(
    *,
    prompt_name: str,
    model: str,
    user: str,
) -> LlmResult:
    client = _client()
    system = prompt_text(prompt_name)
    version = prompt_version(prompt_name)
    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        )
    except Exception as exc:
        raise LlmError(str(exc)) from exc

    usage = response.usage
    return LlmResult(
        content=response.choices[0].message.content or "",
        model=model,
        prompt_version=version,
        tokens_in=usage.prompt_tokens if usage else 0,
        tokens_out=usage.completion_tokens if usage else 0,
    )
