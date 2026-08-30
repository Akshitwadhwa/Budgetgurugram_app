# Gurugram Commons — Event Intelligence

**Design spec · 2026-08-30 · Status: approved, pre-implementation**

This document records *what* we are building and *why*. Implementation detail
lives in [`docs/backend/README.md`](../../backend/README.md) and
[`docs/frontend/README.md`](../../frontend/README.md).

---

## 1. The problem

Every event platform — Luma, Meetup, Eventbrite — shows you the organizer's own
marketing copy. Nothing tells you what the event *actually is*.

The concrete failure: "Claude Meetup Delhi" is listed as a meetup. Anyone who
reads the organizer's site or attended the last three editions knows it is a
hands-on workshop. People show up expecting to network, find themselves in a
build session, and leave. The information existed; it was just scattered across
past editions and the open web.

**Our claim:** *not* "what's happening near me" — **"is this actually worth my
Tuesday evening, and what will it really be like?"**

## 2. Competitive position

| Bucket | Examples | What they own | What they don't |
|---|---|---|---|
| Workspace booking | myHQ, GoFloaters, CoFynd, Qdesq | Inventory, payment, day passes | Only partner venues; no events |
| Laptop-friendly cafés | Workfrom, Nomadable, Cafés To Work From | Crowdsourced wifi/plug/noise data | Thin India coverage; no events |
| Event listings | Luma, Meetup, Eventbrite | Supply and reach | Zero interpretation; organizer copy verbatim |
| Dev tooling | Apify Events Finder | LLM-scores events against a persona | A scraper actor, not a product; no history, no DB |

Nobody does **event interpretation backed by longitudinal memory.** That is the
gap, and it is the entire product.

### Why it is defensible

1. **Longitudinal event memory.** Every scrape is retained forever. After six
   months we know a series has run nine times, is really a workshop, draws ~40
   people, and starts late. This cannot be copied on day one — it accrues.
2. **Series identity resolution.** Recognising that this month's event and last
   month's are the same thing is the hard technical problem, and everything else
   hangs off it.
3. **Grounded Q&A** on top of 1 and 2, with citations.

The moat is the **database**, not the RAG. RAG is how we read the moat.

## 3. Decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D1 | First slice | Event intelligence only | Workspaces are a crowded, solved space with no defensibility. Curated places stay static for now. |
| D2 | Geography | Gurugram-only | Product owner's call. City is a config value so widening is a config change, not a rewrite. |
| D3 | Cold start | Backfill organizer history + live web enrichment | Makes the moat exist on day one rather than in six months. |
| D4 | Stack | Supabase (Postgres + pgvector) + Python worker + thin FastAPI read layer | Vercel Hobby already times out at ~10s on the current events API. Scraping and backfill cannot live in serverless handlers. |
| D5 | LLM | All OpenAI (GPT‑5.6 + `text-embedding-3-small`) | Existing credits and existing `OPENAI_API_KEY` wiring. Cost is a wash vs. alternatives (~$1.50/day either way). |
| D6 | Auth | Anonymous device ID + per-device rate limits | Preserves the zero-friction onboarding already built. Q&A costs money, so identity is needed for abuse control, but a login wall is not. |
| D7 | Trust | Graded claims with visible evidence | The product's value *is* making a judgement the listing doesn't. We allow the judgement but never anonymously. |
| D8 | Intelligence production | Precompute at ingest; narrow RAG for Q&A | Every user sees the same verdict; cost scales with supply (~5 new events/day) not traffic. |
| D9 | Series resolution | Hybrid cheap-first, LLM as tiebreaker | Deterministic where possible; LLM only on genuinely ambiguous pairs. |

### D2 consequence, stated plainly

Gurugram-only means a thin corpus. Series history will often be 1–3 editions,
and "similar events" will sometimes return nothing. The design compensates by
leaning on **web-context enrichment first** and treating observed history as
something that compounds. If the corpus proves too thin to produce useful
verdicts after the backfill, widening to Delhi NCR is the first lever to pull —
`config.city_slugs` is the only thing that changes.

### D7 in detail — the confidence contract

| Confidence | UI language | Example |
|---|---|---|
| ≥ 0.75 | Assertive, hedged | "Likely a hands-on workshop" |
| 0.50 – 0.75 | Tentative | "Possibly a workshop — sources disagree" |
| < 0.50 | **A question, never a statement** | "Format unclear — worth asking the organizer" |

Below 0.50 the event is queued for an escalated deeper research pass. A verdict
is never rendered as a bare label; the evidence that produced it is always one
tap away.

## 4. Architecture

```
┌─────────────┐     reads      ┌──────────────┐
│ Flutter app │ ─────────────▶ │  Read API    │  FastAPI, thin, cached
└─────────────┘                │  (Railway)   │  no LLM in request path
                               └──────┬───────┘   (except POST /ask)
                                      │ SELECT
                               ┌──────▼───────────────────┐
                               │ Supabase Postgres        │
                               │ + pgvector               │  ← the moat
                               └──────▲───────────────────┘
                                      │ writes
                               ┌──────┴───────┐
                               │ Worker       │  discover → resolve → research
                               │ (Railway)    │  → enrich → index → sweep
                               └──────────────┘
```

**Invariant:** no LLM call happens inside a Flutter-facing request except
`POST /v1/events/{id}/ask`. Everything else is precomputed. This is what keeps
the app fast and the bill flat.

## 5. Two schema decisions that carry the design

**Evidence is `NOT NULL`.** Every verdict in `event_enrichment` stores a JSONB
array of `{claim, source_url, source_title, quote}`. A verdict physically cannot
be written without sources. This makes the trust rule a *database constraint*
rather than prompt discipline — the one place it cannot silently rot.

**Events are append-only.** A scraper that breaks and returns zero results must
never delete history. `last_seen_at` goes stale; rows stay. Deleting on empty
scrape is the single most likely way to accidentally destroy the moat, so the
guard is enforced in both the writer and the schema.

**Series verdict is separate from event verdict.** `series.format_verdict` holds
the pattern ("this series is usually a workshop"); `event_enrichment.true_format`
holds this instance's call. When they disagree, that disagreement is itself
useful and is surfaced to the user.

## 6. Cost model

Enrichment is cached per event, so the bill scales with **new events per day
(~5)**, not with scrape frequency (8×/day) or with traffic.

| Line | Volume/day | Cost/day |
|---|---|---|
| Enrichment (batched) | ~5 events × ~35k in / 2k out | ~$0.05 – $0.24 |
| Q&A | ~50 questions × ~10k in / 600 out | ~$0.14 – $1.36 |
| Embeddings | ~5k tokens | ~$0.0000001 |
| **Total** | | **≈ $0.19 – $1.60** |

One-time backfill: ~250 historical events, **≈ $3 – $15**.

**Unpriced risk:** web search is billed per call, not per token, and we could not
confirm current rates. At ~15 calls/day it could plausibly match everything else
combined. Instrument it from day one (`ingest_runs.search_calls`).

**Scaling risk:** Q&A dominates and scales with users. At 5,000 questions/day the
bill goes to ~$100/day. Cache answers per (event, normalized question) and cap
per device.

## 7. Risks, ranked

1. **Scraper fragility.** Luma and Meetup have no friendly public API for this.
   This is the #1 operational risk — higher than anything about the AI. Mitigated
   by per-source isolation, the zero-result guard, and `ingest_runs` telemetry.
2. **Thin Gurugram corpus** (see §D2 consequence).
3. **A confidently wrong verdict.** One bad "beginner-friendly" call destroys the
   trust model. Mitigated by the confidence contract and a labelled eval set that
   must pass before any prompt change ships.
4. **Q&A cost blowup** under traffic.
5. **Backfill scope creep.** Organizer history pages vary wildly in structure.
   Timebox it; partial backfill is fine.

## 8. Out of scope for this slice

Deliberately excluded, not forgotten:

- Workspaces / cafés / coworking intelligence (**stays static curated data**)
- Real accounts, cross-device sync, Supabase Auth
- Notifications, voice briefings, user submissions
- Anything reintroducing the website's header, footer, or Guides section
- Non-Gurugram events

Each is its own later cycle with its own spec.

## 9. Success criteria

The slice is done when:

1. A scheduled worker populates Postgres from all three sources without manual
   intervention for seven consecutive days.
2. Backfill has seeded ≥ 20 organizers with ≥ 1 past edition each.
3. ≥ 60% of upcoming Gurugram events carry a verdict at confidence ≥ 0.50.
4. Every rendered verdict has at least one tappable source.
5. On a hand-labelled set of 30 events, format verdicts are correct ≥ 80% of the
   time, and **no incorrect verdict is rendered above 0.75 confidence** — a
   confident wrong answer counts as a hard failure, not a miss.
6. The Flutter event detail screen opens in < 500ms on cached data.
7. The app still works fully offline against bundled `events.json`.
