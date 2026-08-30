from __future__ import annotations

import logging

from openai import OpenAI

from core.config import get_settings
from core.llm import LlmError

log = logging.getLogger(__name__)
EMBED_DIM = 1536


def embed_texts(texts: list[str]) -> list[list[float]]:
    settings = get_settings()
    if not settings.openai_api_key:
        raise LlmError("OPENAI_API_KEY is not set")
    if not texts:
        return []
    client = OpenAI(api_key=settings.openai_api_key)
    response = client.embeddings.create(model=settings.openai_embed_model, input=texts)
    return [item.embedding for item in response.data]


def embed_one(text: str) -> list[float]:
    return embed_texts([text])[0]


def cosine_distance(a: list[float], b: list[float]) -> float:
    if not a or not b or len(a) != len(b):
        return 1.0
    dot = sum(x * y for x, y in zip(a, b, strict=True))
    na = sum(x * x for x in a) ** 0.5
    nb = sum(y * y for y in b) ** 0.5
    if na == 0 or nb == 0:
        return 1.0
    return 1.0 - (dot / (na * nb))


def cosine_similarity(a: list[float], b: list[float]) -> float:
    return 1.0 - cosine_distance(a, b)
