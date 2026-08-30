# Gurugram Commons — Event Intelligence backend

FastAPI read API + APScheduler worker. Decisions live in
[`docs/superpowers/specs/2026-08-30-event-intelligence-design.md`](../docs/superpowers/specs/2026-08-30-event-intelligence-design.md).
This folder is the implementation of [`docs/backend/README.md`](../docs/backend/README.md).

Two processes, one codebase:

| Process | Command | Role |
|---|---|---|
| **api** | `uvicorn app.main:app --host 0.0.0.0 --port 8000` | Thin read API. No LLM except `POST /v1/events/{id}/ask`. |
| **worker** | `python -m worker.run` | Discover → resolve → research → enrich → index → sweep. |

## Local setup

### macOS / Linux

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

### Windows (PowerShell)

`source` is not a PowerShell command, and the activate script lives at a
different path. Either activate:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1      # not source .venv/bin/activate
pip install -r requirements.txt
Copy-Item .env.example .env
```

…or skip activation entirely and call the venv's interpreter directly. This is
the more reliable option, because it cannot silently install into the wrong
Python and does not depend on `Scripts\` being on `PATH`:

```powershell
cd backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
```

> **If `Activate.ps1` is blocked** by execution policy:
> `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned`
>
> **If `alembic` / `uvicorn` are "not recognized"**, their `Scripts\` directory
> is not on `PATH`. Always invoke them as modules — `python -m alembic`,
> `python -m uvicorn` — which works regardless of `PATH`.

### Then, on every platform

Point `DATABASE_URL` at Supabase (or local Postgres 15 with `pgvector` +
`pg_trgm`). The value in `.env.example` is a **placeholder** — a local install
will have its own password, and `postgres:postgres` will fail with
`password authentication failed for user "postgres"`.

```bash
alembic upgrade head                          # or: python -m alembic upgrade head
uvicorn app.main:app --reload --port 8000     # or: python -m uvicorn app.main:app --reload --port 8000
```

In another terminal:

```bash
python -m worker.run
```

## Producing verdicts

The scheduled worker (`python -m worker.run`) enriches everything it finds.
For the first run against a new prompt or model, use the bounded batch instead —
it caps how many events are processed and reports what they cost:

```bash
python -m worker.enrich_batch --limit 3            # small paid batch
python -m worker.enrich_batch --limit 3 --dry-run  # research + embed only, no paid verdict
python -m worker.enrich_batch --limit 40           # the rest
```

Measured cost: **~$0.009 per verdict** on `gpt-5.6-terra` (~1-3k tokens in,
~0.5k out). Enriching an entire 36-event Gurugram window is well under $0.50.

### What each key buys you

| Key | Without it | With it |
|---|---|---|
| `OPENAI_API_KEY` | No verdicts at all. | Verdicts + embeddings. |
| `SEARCH_API_KEY` (Tavily) | Research falls back to the event's own listing page only. Verdicts still work and are correctly sourced, but they can only ever *agree* with the listing. | Organiser sites, recaps and coverage become citable. |

That second row is the important one. The product's differentiating claim -
catching a listing that misrepresents itself - is **structurally impossible**
without web search, because the listing cannot contradict itself. Expect mostly
`unclear` and listing-echoing verdicts on an OpenAI-only setup.

### Model IDs

`gpt-5.6` and `gpt-5.6-mini` do **not** exist. The real tiers are
`gpt-5.6-sol`, `gpt-5.6-terra` and `gpt-5.6-luna`. Verify against the account
before changing them:

```bash
python -c "from openai import OpenAI; from core.config import get_settings; print([m.id for m in OpenAI(api_key=get_settings().openai_api_key).models.list() if m.id.startswith('gpt-5.6')])"
```

## Exporting a readable copy

SQLite is the engine; `export.json` is the human-readable view.

```bash
python -m worker.export_json                      # -> data/export.json
python -m worker.export_json --include-embeddings # very large; rarely wanted
```

One-off history backfill (partial is acceptable):

```bash
python -m worker.backfill --organizers-from-live --limit 20
```

Every request needs `X-Device-Id`. Example:

```bash
curl -H "X-Device-Id: 11111111-1111-1111-1111-111111111111" \
  http://127.0.0.1:8000/v1/events
```

## Tests

```bash
cd backend
pytest
```

These cover the non-negotiable rules: zero-result guard, evidence / citation /
quote grounding, confidence bands, Q&A refusal without an LLM call, rate limit,
and the series-title golden set.

## Deploy

- **Supabase** — Postgres + pgvector. Run `alembic upgrade head` on deploy.
- **Railway** — two services from this folder:
  - api: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
  - worker: `python -m worker.run`

The existing Vercel site stays as-is. The Flutter app switches over by changing
`ApiConfig.baseUrl` to this API.
