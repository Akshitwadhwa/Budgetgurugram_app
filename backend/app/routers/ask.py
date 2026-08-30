from __future__ import annotations

import json
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from core.config import get_settings
from core.embeddings import cosine_similarity, embed_one
from core.llm import LlmError, complete_structured
from core.models import Device, Event, EventChunk, QaMessage
from core.qa import REFUSAL_MESSAGE, normalize_question, should_refuse, strip_ungrounded_citations

from app.deps import enforce_qa_limit, get_db
from app.schemas.ask import AskCitation, AskRequest, AskResponse

router = APIRouter(prefix="/v1", tags=["ask"])

ASK_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["answer", "citations", "refused"],
    "properties": {
        "answer": {"type": "string"},
        "refused": {"type": "boolean"},
        "citations": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": ["source_url", "source_title", "quote"],
                "properties": {
                    "source_url": {"type": "string"},
                    "source_title": {"type": "string"},
                    "quote": {"type": "string"},
                },
            },
        },
    },
}


def _retrieve_chunks(session: Session, event: Event) -> list[EventChunk]:
    stmt = select(EventChunk)
    if event.series_id and event.organizer_id:
        past_ids = session.scalars(select(Event.id).where(Event.series_id == event.series_id)).all()
        organizer_event_ids = session.scalars(
            select(Event.id).where(Event.organizer_id == event.organizer_id)
        ).all()
        stmt = stmt.where(
            EventChunk.event_id.in_({event.id, *past_ids, *organizer_event_ids})
            | (EventChunk.series_id == event.series_id)
        )
    elif event.series_id:
        stmt = stmt.where((EventChunk.event_id == event.id) | (EventChunk.series_id == event.series_id))
    else:
        stmt = stmt.where(EventChunk.event_id == event.id)
    return list(session.scalars(stmt).all())


@router.post("/events/{event_id}/ask", response_model=AskResponse)
def ask_event(
    event_id: UUID,
    body: AskRequest,
    device: Device = Depends(enforce_qa_limit),
    session: Session = Depends(get_db),
) -> AskResponse:
    event = session.get(Event, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")

    question_key = normalize_question(body.question)
    cached = session.scalar(
        select(QaMessage).where(
            QaMessage.event_id == event.id,
            QaMessage.question_key == question_key,
            QaMessage.answer.is_not(None),
        )
    )
    if cached:
        return AskResponse(
            answer=cached.answer or REFUSAL_MESSAGE,
            citations=[AskCitation.model_validate(item) for item in cached.citations or []],
            refused=cached.refused,
        )

    chunks = _retrieve_chunks(session, event)
    settings = get_settings()

    ranked: list[tuple[float, EventChunk]] = []
    try:
        query_vec = embed_one(body.question)
        for chunk in chunks:
            ranked.append((cosine_similarity(query_vec, list(chunk.embedding)), chunk))
        ranked.sort(key=lambda item: item[0], reverse=True)
        ranked = ranked[:8]
    except LlmError:
        ranked = []

    similarities = [score for score, _ in ranked]
    if should_refuse(similarities, settings.retrieval_min_similarity):
        message = QaMessage(
            device_id=device.id,
            event_id=event.id,
            question=body.question,
            question_key=question_key,
            answer=REFUSAL_MESSAGE,
            citations=[],
            refused=True,
        )
        session.add(message)
        return AskResponse(answer=REFUSAL_MESSAGE, citations=[], refused=True)

    allowed_urls = {chunk.source_url for _, chunk in ranked if chunk.source_url}
    context = []
    for score, chunk in ranked:
        context.append(
            {
                "source_url": chunk.source_url,
                "source_type": chunk.source_type,
                "content": chunk.content[:2000],
                "similarity": round(score, 3),
            }
        )
    user = json.dumps(
        {
            "event": {"title": event.title, "url": event.url, "description": event.description_raw},
            "question": body.question,
            "chunks": context,
        }
    )

    try:
        result = complete_structured(
            prompt_name="ask.md",
            model=settings.openai_model_ask,
            user=user,
            schema=ASK_SCHEMA,
            schema_name="ask_response",
        )
    except LlmError:
        message = QaMessage(
            device_id=device.id,
            event_id=event.id,
            question=body.question,
            question_key=question_key,
            answer=REFUSAL_MESSAGE,
            citations=[],
            refused=True,
        )
        session.add(message)
        return AskResponse(answer=REFUSAL_MESSAGE, citations=[], refused=True)

    payload = result.content
    citations = strip_ungrounded_citations(payload.get("citations") or [], allowed_urls)
    refused = bool(payload.get("refused"))
    answer = payload.get("answer") or REFUSAL_MESSAGE
    if refused:
        answer = payload.get("answer") or REFUSAL_MESSAGE

    message = QaMessage(
        device_id=device.id,
        event_id=event.id,
        question=body.question,
        question_key=question_key,
        answer=answer,
        citations=citations,
        refused=refused,
        tokens_in=result.tokens_in,
        tokens_out=result.tokens_out,
    )
    session.add(message)
    return AskResponse(
        answer=answer,
        citations=[AskCitation.model_validate(item) for item in citations],
        refused=refused,
    )
