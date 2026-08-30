# Backend — Event Intelligence

Implementation guide. Decisions and rationale live in
[the design spec](../superpowers/specs/2026-08-30-event-intelligence-design.md).

---

## 1. Layout

Two deployables in one repo (`budgetgurugram-backend`, new):

```
backend/
  app/
    main.py                 FastAPI read API
    deps.py                 db session, device auth, rate limit
    routers/
      events.py             GET /v1/events, /v1/events/{id}
      ask.py                POST /v1/events/{id}/ask
      health.py             GET /v1/health
    schemas/                Pydantic response models (the app's contract)
  worker/
    run.py                  APScheduler entrypoint
    stages/
      discover.py           per-source scraping
      resolve.py            organizer + series identity
      research.py           web search, fetch, cache, chunk
      enrich.py             the verdict call
      index.py              embeddings + similarity
      sweep.py              past-marking, series stats
    sources/
      base.py               Source protocol
      luma.py
      meetup.py
      community_meetups.py
    backfill.py             one-off historical seeding
  core/
    config.py               env + city config
    db.py                   SQLAlchemy engine/session
    llm.py                  OpenAI client wrapper (single chokepoint)
    embeddings.py
    websearch.py            search + fetch + cache
    prompts/
      enrich.md
      series_match.md
      ask.md
  migrations/               Alembic
  tests/
```

**Rule:** every OpenAI call goes through `core/llm.py`. One place to add
retries, logging, token accounting, prompt versioning, and batching.

## 2. Database schema

Postgres 15 + `pgvector` + `pg_trgm`, hosted on Supabase.

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ── sources ─────────────────────────────────────────────────────────────
CREATE TABLE sources (
  id            text PRIMARY KEY,            -- 'luma' | 'meetup' | 'community'
  display_name  text NOT NULL,
  enabled       boolean NOT NULL DEFAULT true,
  config        jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ── organizers ──────────────────────────────────────────────────────────
CREATE TABLE organizers (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id         text REFERENCES sources(id),
  source_ref        text,                    -- host/group slug on that source
  name              text NOT NULL,
  normalized_name   text NOT NULL,
  url               text,
  socials           jsonb NOT NULL DEFAULT '[]'::jsonb,
  profile_summary   text,
  profile_evidence  jsonb NOT NULL DEFAULT '[]'::jsonb,
  embedding         vector(1536),
  first_seen_at     timestamptz NOT NULL DEFAULT now(),
  last_seen_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source_id, source_ref)
);
CREATE INDEX organizers_name_trgm ON organizers USING gin (normalized_name gin_trgm_ops);

-- ── series: the moat ────────────────────────────────────────────────────
CREATE TABLE series (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_id       uuid REFERENCES organizers(id),
  canonical_title    text NOT NULL,
  normalized_key     text NOT NULL,          -- title with edition markers stripped
  format_verdict     text,                   -- see enum in §4
  format_confidence  real,
  level              text,
  cadence            text,                   -- 'monthly' | 'weekly' | 'irregular'
  typical_attendance int,
  summary            text,
  evidence           jsonb NOT NULL DEFAULT '[]'::jsonb,
  embedding          vector(1536),
  editions_count     int NOT NULL DEFAULT 0,
  first_seen_at      timestamptz NOT NULL DEFAULT now(),
  last_seen_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX series_key_trgm ON series USING gin (normalized_key gin_trgm_ops);
CREATE INDEX series_embedding ON series USING hnsw (embedding vector_cosine_ops);

-- ── events: append-only ─────────────────────────────────────────────────
CREATE TABLE events (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id        text NOT NULL REFERENCES sources(id),
  source_event_id  text NOT NULL,
  series_id        uuid REFERENCES series(id),
  organizer_id     uuid REFERENCES organizers(id),
  title            text NOT NULL,
  description_raw  text NOT NULL DEFAULT '',
  starts_at        timestamptz NOT NULL,
  ends_at          timestamptz,
  venue_name       text,
  address          text,
  lat              double precision,
  lng              double precision,
  geocode_quality  text,                     -- 'exact'|'area'|'city-default'|'unlocated'
  price_raw        text,
  price_value      numeric,
  url              text NOT NULL,
  city             text NOT NULL DEFAULT 'Gurugram',
  status           text NOT NULL DEFAULT 'upcoming',  -- upcoming|past|cancelled
  raw              jsonb NOT NULL,
  embedding        vector(1536),
  first_seen_at    timestamptz NOT NULL DEFAULT now(),
  last_seen_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source_id, source_event_id)
);
CREATE INDEX events_starts_at ON events (starts_at);
CREATE INDEX events_series ON events (series_id);
CREATE INDEX events_embedding ON events USING hnsw (embedding vector_cosine_ops);

-- ── the verdict ─────────────────────────────────────────────────────────
CREATE TABLE event_enrichment (
  event_id          uuid PRIMARY KEY REFERENCES events(id) ON DELETE CASCADE,
  true_format       text NOT NULL,
  format_confidence real NOT NULL CHECK (format_confidence BETWEEN 0 AND 1),
  level             text,
  hands_on          boolean,
  expect            text NOT NULL,
  who_should_come   jsonb NOT NULL DEFAULT '[]'::jsonb,
  prep_needed       text,
  watch_outs        jsonb NOT NULL DEFAULT '[]'::jsonb,
  evidence          jsonb NOT NULL,
  escalated         boolean NOT NULL DEFAULT false,
  model             text NOT NULL,
  prompt_version    text NOT NULL,
  tokens_in         int,
  tokens_out        int,
  created_at        timestamptz NOT NULL DEFAULT now(),
  -- the trust rule, as a constraint
  CONSTRAINT evidence_required CHECK (jsonb_array_length(evidence) > 0)
);

-- ── RAG corpus ──────────────────────────────────────────────────────────
CREATE TABLE web_documents (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  url          text NOT NULL UNIQUE,
  title        text,
  content      text NOT NULL,
  content_hash text NOT NULL,
  fetched_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE event_chunks (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id     uuid REFERENCES events(id) ON DELETE CASCADE,
  series_id    uuid REFERENCES series(id) ON DELETE CASCADE,
  source_type  text NOT NULL,   -- 'description'|'web_doc'|'past_edition'
  source_url   text,
  content      text NOT NULL,
  embedding    vector(1536) NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX event_chunks_embedding ON event_chunks USING hnsw (embedding vector_cosine_ops);
CREATE INDEX event_chunks_event ON event_chunks (event_id);

CREATE TABLE event_similarity (
  event_id      uuid REFERENCES events(id) ON DELETE CASCADE,
  similar_id    uuid REFERENCES events(id) ON DELETE CASCADE,
  score         real NOT NULL,
  PRIMARY KEY (event_id, similar_id)
);

-- ── devices & Q&A ───────────────────────────────────────────────────────
CREATE TABLE devices (
  id            text PRIMARY KEY,            -- client-generated UUID
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz NOT NULL DEFAULT now(),
  blocked       boolean NOT NULL DEFAULT false
);

CREATE TABLE qa_messages (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id    text NOT NULL REFERENCES devices(id),
  event_id     uuid NOT NULL REFERENCES events(id),
  question     text NOT NULL,
  question_key text NOT NULL,                -- normalized, for answer caching
  answer       text,
  citations    jsonb NOT NULL DEFAULT '[]'::jsonb,
  refused      boolean NOT NULL DEFAULT false,
  tokens_in    int,
  tokens_out   int,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX qa_device_day ON qa_messages (device_id, created_at);
CREATE INDEX qa_cache ON qa_messages (event_id, question_key);

-- ── observability ───────────────────────────────────────────────────────
CREATE TABLE ingest_runs (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id      text NOT NULL REFERENCES sources(id),
  started_at     timestamptz NOT NULL DEFAULT now(),
  finished_at    timestamptz,
  status         text NOT NULL DEFAULT 'running',  -- running|ok|failed|suspect
  events_found   int NOT NULL DEFAULT 0,
  events_new     int NOT NULL DEFAULT 0,
  events_enriched int NOT NULL DEFAULT 0,
  search_calls   int NOT NULL DEFAULT 0,
  errors         jsonb NOT NULL DEFAULT '[]'::jsonb
);
```

## 3. Worker pipeline

Scheduled with APScheduler inside the worker process. `discover` runs every
3 hours; everything downstream is triggered by what `discover` produced.

### 3.1 `discover`

Per enabled source, fetch Gurugram listings and upsert into `events` on
`(source_id, source_event_id)`. Always writes `raw`. Bumps `last_seen_at`.

**Zero-result guard — the most important safety rule in the system:**

```python
if found == 0 and last_successful_run_found > 0:
    run.status = "suspect"
    log_alert(f"{source_id} returned 0 events; previous run found {n}")
    return  # do NOT mark anything past, do NOT delete
```

A source that breaks must degrade to stale data, never to empty data. Each
source is isolated — one throwing does not abort the others.

### 3.2 `resolve`

Organizer first (exact `source_ref` match, else trigram on `normalized_name`),
then series:

1. **Normalize** the title — strip edition markers: `#12`, `Vol. 3`,
   `— December Edition`, `2026`, ordinals, month names.
2. **Generate candidates** — same organizer AND (`normalized_key` trigram
   similarity > 0.6 OR embedding cosine distance < 0.15). Cheap, deterministic.
3. **Adjudicate** — if exactly one candidate above the high threshold, match it
   with no LLM call. If 0 candidates, create a new series. Only if there are
   multiple candidates, or one in the ambiguous band, call the LLM with
   `prompts/series_match.md` to decide.

The LLM is a tiebreaker, not a matcher. Most events resolve for free.

### 3.3 `research` (new events only)

1. Build search queries: the series name, the organizer name, `"<title>" review`,
   the organizer's domain.
2. Search, take the top N results, fetch each. Cache into `web_documents` by URL;
   skip refetch if `fetched_at` is recent and `content_hash` matches.
3. Pull the series' past editions from `events`.
4. Chunk (≈800 tokens, 100 overlap), embed, write to `event_chunks` **with
   `source_url` on every chunk** — a chunk without provenance cannot later back
   a claim.

Increment `ingest_runs.search_calls` on every search — this is the unpriced cost
line and must be visible from day one.

### 3.4 `enrich`

One structured-output call per new event via the Batch API (50% cheaper; this is
not latency-sensitive). Context: the raw listing, retrieved chunks, past
editions, the organizer profile.

Response schema (`response_format` JSON schema, strict):

```json
{
  "true_format": "workshop|talk|panel|networking|hackathon|demo_day|social|conference|unclear",
  "format_confidence": 0.0,
  "level": "beginner|intermediate|advanced|mixed|unclear",
  "hands_on": true,
  "expect": "2-3 sentences on what actually happens",
  "who_should_come": ["..."],
  "prep_needed": "... or null",
  "watch_outs": ["..."],
  "evidence": [
    {"claim": "...", "source_url": "...", "source_title": "...", "quote": "..."}
  ]
}
```

**Write-time validation, before the INSERT:**

- `evidence` non-empty, else reject the whole enrichment.
- Every `source_url` must appear in this event's `event_chunks` or
  `web_documents`. A cited URL the pipeline never fetched is a hallucination —
  reject.
- Every `quote` must be a substring of its source document. Reject on mismatch.
- `format_confidence < 0.5` → write it, set `escalated = false`, and queue for
  the deeper pass.

Rejected enrichments are logged to `ingest_runs.errors` and retried once. An
event with no enrichment is still served — the app renders the raw listing.

### 3.5 `index`

Embed the event, compute top-5 nearest neighbours among upcoming events
(excluding same-series), write `event_similarity`.

### 3.6 `sweep`

Mark past events, recompute `series.editions_count`, `cadence`, and roll up a
series-level `format_verdict` from its editions' verdicts.

### 3.7 `backfill` (one-off)

`python -m worker.backfill --organizers-from-live`. For each organizer already
discovered, fetch their past-events page, run the same stages. **Timebox this.**
Organizer history pages vary wildly; partial backfill is an acceptable outcome
and a `--limit` flag exists for that reason.

## 4. Read API

Base `/v1`. Every request carries `X-Device-Id`. All list responses cached 5 min.

| Method | Path | Returns |
|---|---|---|
| GET | `/v1/events` | Upcoming events + verdict summary. Query: `from`, `to`, `filter=today\|week\|free`, `limit`, `cursor` |
| GET | `/v1/events/{id}` | Event + enrichment + evidence + series + past editions + similar events |
| POST | `/v1/events/{id}/ask` | `{question}` → `{answer, citations[], refused}` |
| GET | `/v1/health` | Per-source last run status, staleness, counts |

`GET /v1/events/{id}` response shape (the frontend contract):

```json
{
  "event": { "id": "...", "title": "...", "startsAt": "...", "venueName": "...",
             "lat": null, "lng": null, "geocodeQuality": "area",
             "priceRaw": "See source", "url": "...", "source": "Luma" },
  "verdict": {
    "trueFormat": "workshop", "confidence": 0.82, "band": "likely",
    "level": "intermediate", "handsOn": true,
    "expect": "...", "whoShouldCome": ["..."], "prepNeeded": "...",
    "watchOuts": ["..."],
    "evidence": [{"claim": "...", "sourceUrl": "...", "sourceTitle": "...", "quote": "..."}]
  },
  "series": { "id": "...", "canonicalTitle": "...", "editionsCount": 9,
              "cadence": "monthly", "formatVerdict": "workshop",
              "disagreesWithEvent": false },
  "pastEditions": [{"id": "...", "title": "...", "startsAt": "...", "url": "..."}],
  "similar": [{"id": "...", "title": "...", "startsAt": "...", "score": 0.81}]
}
```

`verdict` is **nullable** — the app must render a usable page without it.
`band` is computed server-side (`likely` / `possibly` / `unclear`) so the app
never reimplements the threshold logic.

### Q&A endpoint

1. Rate limit: 20 questions/device/day → `429` with `retryAfter`.
2. Normalize the question → `question_key`; if an answer exists for
   `(event_id, question_key)`, return it cached and free.
3. Retrieve top-8 chunks scoped to **this event ∪ its series' past editions ∪
   its organizer's documents**. Never the whole corpus.
4. If retrieval is empty or max similarity is below threshold, return
   `refused: true` with a plain message. **Do not call the LLM.** Refusing is
   correct behaviour, not a failure.
5. Otherwise generate with `prompts/ask.md`, requiring citations that map to
   retrieved chunk `source_url`s. Strip any citation that doesn't.

## 5. Configuration

```
DATABASE_URL=            # Supabase pooled connection string
OPENAI_API_KEY=
OPENAI_MODEL_ENRICH=     # GPT-5.6 tier for enrichment
OPENAI_MODEL_ASK=        # tier for user-facing Q&A
OPENAI_MODEL_MATCH=      # cheap tier for series tiebreaks
OPENAI_EMBED_MODEL=text-embedding-3-small
SEARCH_API_KEY=
CITY_SLUGS=gurugram,gurgaon
CITY_CENTER_LAT=28.4945
CITY_CENTER_LNG=77.0894
CITY_BBOX=28.35,76.92,28.56,77.16
QA_DAILY_LIMIT=20
SCRAPE_INTERVAL_HOURS=3
```

`CITY_*` is the whole of D2. Widening to Delhi NCR later is editing these values.

## 6. Error handling

| Failure | Behaviour |
|---|---|
| One source throws | Isolated; other sources proceed. Logged to `ingest_runs.errors`. |
| Source returns 0 (previously >0) | `status='suspect'`, keep all data, alert. Never delete. |
| Geocode missing/city-default | Store `geocode_quality`; app shows "Confirm venue on source", never a fabricated distance. |
| Enrichment invalid (bad evidence) | Reject, log, retry once. Event served without verdict. |
| Enrichment LLM down | Event served without verdict; requeued next run. |
| Embedding fails | Event stored, `embedding` null, excluded from similarity until backfilled. |
| Q&A retrieval empty | Refuse with a message. No LLM call. |
| API down | Flutter falls back to bundled `assets/data/events.json` (already implemented). |

## 7. Testing

| Area | Test |
|---|---|
| **Zero-result guard** | Source returns 0 after a run of 40 → nothing deleted, run marked `suspect`. Non-negotiable. |
| **Evidence constraint** | Enrichment with empty `evidence` → INSERT rejected by the DB. |
| **Citation grounding** | Enrichment citing a URL not in `web_documents` → rejected at write time. |
| **Quote grounding** | A `quote` not present in its source doc → rejected. |
| Series resolution | Hand-labelled golden set of ~40 title pairs, including the `#12` / `December Edition` case. Must not merge distinct series. |
| Title normalization | Unit tests per edition-marker pattern. |
| Format verdicts | Labelled eval set of 30 events. ≥80% correct, **and zero incorrect verdicts above 0.75 confidence.** Gates every prompt change. |
| Q&A refusal | Empty retrieval → refuses, and makes no LLM call. |
| Rate limiting | 21st question in a day → 429. |
| Confidence bands | Boundary values 0.49 / 0.50 / 0.74 / 0.75 map to the right band. |

Run the eval set in CI on any change to `core/prompts/`.

## 8. Deploy

- **Supabase** — Postgres + pgvector. Alembic migrations run on deploy.
- **Railway** — two services from one repo: `api` (`uvicorn app.main:app`) and
  `worker` (`python -m worker.run`). The worker is not behind HTTP and has no
  request timeout, which is the entire reason it exists separately.
- Existing Vercel site stays as-is. The app stops calling it once `/v1/events`
  is live; `ApiConfig.baseUrl` in the Flutter app is the only switch.
