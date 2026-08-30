# Frontend — Event Intelligence

Flutter implementation for the event-intelligence slice. Decisions live in
[the design spec](../superpowers/specs/2026-08-30-event-intelligence-design.md);
the API contract is in [`docs/backend/README.md §4`](../backend/README.md); the
visual system and its reasoning are in [`DESIGN.md`](./DESIGN.md).

## Status

**Built and passing** (`flutter analyze` clean, 13 tests green):

- Full design-token system — `app_tokens`, `app_palette` (light + dark via
  `ThemeExtension`), `app_typography`, `app_theme`
- `ConfidenceMeter`, `DashedBorderPainter`, `VerdictCard`, `VerdictPendingCard`,
  `EvidenceSheet`, `AskSheet`, `Reveal`, `Skeleton`, `SectionLabel`, `MetaPill`
- `EventDetailScreen` — the screen that replaces bouncing users out to Luma
- Mapbox tiles + custom-drawn `MapPin` / `ClusterPin` / `UserLocationPin`
- Every screen migrated off the legacy palette; `app_colors.dart` deleted
- Renamed throughout to **Budget Gurugram** (Dart package, Android label,
  iOS bundle name, wordmark)
- `verdict_test.dart` — trust-model invariants

**Running on fixtures.** `lib/data/mock_intelligence.dart` stands in for the
backend: deterministic (stable hash, not `Random()`), and weighted so all three
confidence bands plus the no-verdict state appear in any demo. Swapping it for
a real `ApiClient` touches that one file — the widget layer takes an
`EventVerdict` and never learns where it came from.

**Not built yet:** `ApiClient`, `DeviceService`, the `AppState` split (§6), the
offline response cache. Those are backend-dependent or pure refactors and are
listed in §10.

---

## 1. What changes, and what doesn't

**Unchanged.** Design tokens, fonts, bottom nav, onboarding, Explore, Map,
Saved, Profile, curated places, offline fallback. The component split
(`screens/` · `widgets/` · `services/` · `state/`) stays.

**The one product change:** today an event card's only action is
`launchUrl(event.url)` — it throws the user out to Luma. That is precisely the
behaviour the product exists to replace. Events now open an **in-app detail
screen** carrying the verdict, its evidence, past editions, similar events, and
Ask.

## 2. New and changed files

```
lib/
  models/
    event_item.dart          CHANGED  + seriesId, verdictBand, hasVerdict
    event_verdict.dart       NEW      verdict + confidence band
    evidence.dart            NEW      claim / sourceUrl / sourceTitle / quote
    event_series.dart        NEW      series summary + past editions
    qa_message.dart          NEW
  services/
    api_config.dart          CHANGED  point at the new backend
    api_client.dart          NEW      single HTTP chokepoint, injects X-Device-Id
    device_service.dart      NEW      generate + persist device UUID
    events_service.dart      CHANGED  use ApiClient; keep bundled fallback
  state/
    app_state.dart           CHANGED  slimmed — see §6
    event_detail_state.dart  NEW      per-event detail + Q&A
  screens/
    event_detail_screen.dart NEW      the centrepiece
  widgets/
    verdict_card.dart        NEW
    evidence_sheet.dart      NEW
    past_editions_strip.dart NEW
    similar_events_strip.dart NEW
    ask_sheet.dart           NEW
    confidence_chip.dart     NEW
```

## 3. The verdict UI — where the trust model becomes pixels

The band comes from the server (`likely` / `possibly` / `unclear`). **The app
never computes it from a raw confidence number** — one thresholding rule, one
place, server-side.

| Band | Headline | Chip | Tone |
|---|---|---|---|
| `likely` (≥0.75) | "Likely a hands-on workshop" | forest, filled | Assertive but hedged |
| `possibly` (0.50–0.75) | "Possibly a workshop — sources disagree" | gold, outlined | Visibly tentative |
| `unclear` (<0.50) | "Format unclear — worth asking the organizer" | muted, outlined | **A question, never a claim** |
| `null` | *No verdict block at all* | — | Render the raw listing, nothing more |

Rules that are not negotiable:

- **A verdict is never rendered without its evidence affordance.** `VerdictCard`
  takes a non-nullable `List<Evidence>`; an empty list is a programming error.
  There is no code path that shows a conclusion with no way to check it.
- **Tapping the evidence count opens `EvidenceSheet`** listing each claim with
  its source title, quote, and a tappable link out.
- The `unclear` band renders as a prompt to act, not a label. No fake certainty.
- When `series.disagreesWithEvent` is true, show a line: *"This series is usually
  a talk, but this edition looks hands-on."* Disagreement is information.

## 4. `EventDetailScreen`

Scroll order, top to bottom:

1. **Header** — title, date/time, source badge, `Text.rich` serif treatment
   matching `EventsScreen`.
2. **Venue** — name + area. If `geocodeQuality` is `city-default` or
   `unlocated`, show **"Confirm venue on source"** and **no distance**. Never a
   fabricated km. (Carried over from the existing handoff rule.)
3. **`VerdictCard`** — band headline, `expect` prose, level, hands-on,
   `ConfidenceChip`, and "Based on N sources ›" opening `EvidenceSheet`.
   Omitted entirely when `verdict == null`.
4. **Who should come / prep needed / watch-outs** — only when non-empty.
5. **`PastEditionsStrip`** — horizontal, "Run 9 times · usually monthly".
   Hidden when the series has no history (common early — hide, don't show an
   empty state).
6. **`SimilarEventsStrip`** — horizontal cards, taps push a new detail screen.
7. **Ask** — a pill button opening `AskSheet`.
8. **Footer** — "Open on Luma ↗" and the standard sourcing disclaimer.

**Loading:** skeleton placeholders, not a spinner — the page has known structure.
**Error:** if the detail call fails but we already have the list-level
`EventItem`, render header + footer from it and show an inline retry for the
enriched half. A network failure degrades the page; it never blanks it.

## 5. `AskSheet`

A bottom sheet, consistent with `showPlaceSheet`.

- Suggested starter questions: *"Is this beginner-friendly?"*, *"What should I
  bring?"*, *"Is it really a workshop?"*
- Answers render with **inline numbered citations**; tapping one opens the source.
- `refused: true` renders the backend's message verbatim in muted style. **Do not
  dress a refusal up as an answer.** "I don't have enough on this one" is the
  correct output and should look like a deliberate answer, not an error.
- `429` → "You've asked 20 questions today. Resets tomorrow." Friendly, not alarming.
- Questions and answers persist per event in `shared_preferences` so reopening
  the sheet keeps the thread.

## 6. State

`lib/state/app_state.dart` is already the largest file at 323 lines and carries
places, events, weather, filters, location, and scoring. Adding detail + Q&A
would push it past the point of being reasonable to work in.

Split it as part of this work — targeted, not speculative refactoring:

| New | Owns |
|---|---|
| `ProfileController` | profile, onboarding, location, saved |
| `PlacesController` | curated, nearby, map filters, place scoring |
| `EventsController` | event list, filters, event scoring |
| `EventDetailState` | one event's detail + Q&A thread (created per screen) |

`AppState` becomes a thin composition root so `main.dart` and existing screens
change as little as possible. Move the pure functions (`_haversine`,
`_nearestArea`, `_fitPercent`) into `lib/core/geo.dart` and
`lib/core/scoring.dart` — they are the parts most worth unit-testing and they
currently sit inside a `ChangeNotifier` where tests can't reach them cleanly.

## 7. Device identity

`DeviceService` generates a UUID v4 on first run, stores it in
`shared_preferences` under `gc-device-id`, and `ApiClient` attaches it as
`X-Device-Id` on every request. No login, no prompt, no account UI — the user
never sees this.

## 8. Offline and degradation

The existing fallback chain stays and extends:

1. Live `/v1/events` → full experience.
2. API unreachable → bundled `assets/data/events.json`, **verdict UI hidden
   entirely.** No stale verdicts, no half-claims.
3. Detail call fails → header + footer from the cached list item, inline retry.
4. Ask offline → disabled with "Ask needs a connection".

Cache the last successful `/v1/events` response in `shared_preferences` so a
cold start without network beats the bundled file when possible.

## 9. Tests

| Area | Test |
|---|---|
| Confidence bands | Each band renders the correct headline, chip colour, and tone |
| Evidence invariant | `VerdictCard` with an empty evidence list fails loudly |
| Null verdict | Detail screen renders fully with `verdict == null` |
| Geocode quality | `city-default` renders "Confirm venue on source" and **no** distance |
| Refusal | `refused: true` renders the message, not an empty answer bubble |
| Rate limit | 429 renders the friendly cap message |
| Offline | With the API stubbed to fail, the list still populates from the bundle and no verdict UI appears |
| Scoring / geo | Unit tests on the extracted `core/` functions |

## 10. Sequencing

1. `DeviceService` + `ApiClient` + `ApiConfig` — plumbing, no visible change.
2. Extract `core/geo.dart`, `core/scoring.dart` with tests. Pure refactor.
3. Split `AppState`. Pure refactor; existing screens keep working.
4. Models: `EventVerdict`, `Evidence`, `EventSeries`, `QaMessage`.
5. `EventDetailScreen` with header/venue/footer only, wired from `EventCard`.
   **Ship-able here** — already better than bouncing to Luma.
6. `VerdictCard` + `ConfidenceChip` + `EvidenceSheet`.
7. `PastEditionsStrip` + `SimilarEventsStrip`.
8. `AskSheet`.

Steps 1–3 are safe against today's backend and can land before the API exists.
