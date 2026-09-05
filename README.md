# Budget Gurugram

A phone app for people in **Gurugram**. It answers one everyday question: where should I eat, work, pause, or show up today — near me, on my budget, without guessing?

**Eat, work, pause, or show up — one app.**

Not a generic India directory. Not a booking site. Not another Luma clone. A one-stop city companion: nearby places and public events in the same app, ranked for you, with sources you can check.

## Who it is for

Students, young professionals, founders, residents, and visitors who today jump between Maps, Instagram, Luma, Meetup, and WhatsApp — and still show up to the wrong thing, or stay home.

## What we are building

| Surface | What it does |
|---|---|
| **Intro** | First-launch city title card, then 3-step onboarding (motive, role, location). |
| **Explore** | Weather, “best for you” places and events, search, category and area filters. |
| **Map** | Nearby pins plus a small curated guide. Tap a pin for details, save, directions. |
| **Events** | Gurugram-only listings from public calendars. In-app detail instead of a bounce to Luma. A verdict with evidence when we have it: meetup or workshop, what to expect. |
| **Saved / Profile** | Shortlist and preferences on this device. No account required to browse. |

**Next:** a **Today** brief that stitches weather, a place, and an event into one day plan — still one city, one app.

Website chrome (header, footer, editorial Guides) stays out. Navigation is a bottom bar.

## How it works

- **Flutter** app (iOS + Android). Offline floor: curated places and `assets/data/events.json`.
- **Read API** serves events the worker has already prepared. Scraping and enrichment do not run on the phone’s request.
- **Trust:** we do not claim “open now” or verified prices without a source. A verdict cannot ship without evidence. Events with no real venue say “Confirm venue on source” — we do not invent a kilometre.
- Places nearby still come from the existing Vercel / Geoapify path when live data is available; the map falls back to guide pins if it is not.

## Run

```bash
cd Budgetgurugram_app
flutter pub get
flutter run
```

Optional:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api-host
```

Needs a simulator or device. Location permission strings are already in iOS `Info.plist` and Android `AndroidManifest.xml`.

The app reads the events API you point it at, then last-good cache, then bundled `assets/data/events.json`. Nearby places use `https://budgetgurugram.vercel.app` when that host is the one configured.

## Backend

Event intelligence (discover → resolve → research → enrich) lives in `backend/`. See `backend/README.md` and `docs/superpowers/specs/2026-08-30-event-intelligence-design.md`.
