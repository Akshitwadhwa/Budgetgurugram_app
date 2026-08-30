# Gurugram Commons — app handoff

Read this first if you are continuing work on the **Flutter mobile app**.

This is a local-first city guide for **Gurugram (Gurgaon), India**. The product name in the UI is **Gurugram Commons**. The original website repo is **BudgetGurugram**. The app is a phone-native version of that website: same idea, same data sources, no website header/footer.

---

## What I am building

A usable mobile app that helps someone in Gurugram decide **where to eat, work, pause, or go to an event today**.

It is not a generic city directory. The point of view is:

- Affordable / clearly priced places
- Source-labeled data (do not pretend hours or prices are verified)
- Personalised by motive, role, and neighbourhood
- Live events from public calendars (Luma / Meetup), **Gurugram only**
- Live nearby pins from a places API, plus a small curated guide

Target user: tech people, founders, students, residents, visitors who want a simple “what should I do near me?” companion.

---

## Two folders

| Folder | What it is |
|--------|------------|
| `/Users/Lenovo/Desktop/Summer 2026/Josh Tech work/budgetgurugram` | Original **website** (vanilla HTML/JS). Hosted on Vercel. This is the **backend / API**. |
| `/Users/Lenovo/Desktop/Summer 2026/Josh Tech work/budgetgurugramapp` | **Flutter app** (this repo). iOS + Android. This is what you should work on. |

Do **not** turn the website into the app. Keep working in `budgetgurugramapp`. The website stays the API + fallback data.

---

## Product features (keep these)

1. **Onboarding (3 steps)** — motive (eat / work / events / parks / services / explore), optional role, location (GPS or neighbourhood).
2. **Explore** — weather, “best for you” recommendations, search, category + area filters, place cards, save.
3. **Map** — OSM tiles, live nearby pins, optional curated guide pins, event pins, tap a pin → details sheet.
4. **Events** — live Gurugram events, “Best for you” sort, today / week / free filters, event map, open source URL.
5. **Saved** — local saved places.
6. **Profile** — name, role, starting area. Stored on device.

Removed on purpose (do not bring back unless asked):

- Website header, footer, editorial “Guides” section
- Desktop-only chrome (⌘K, wide nav)
- Gender as an auth signal

---

## What is already done

### Flutter app (`budgetgurugramapp`)

Scaffolded with `flutter create`, package name `gurugram_commons`, org `com.gurugramcommons`.

**Architecture (component-based):**

```
lib/
  main.dart
  theme/          app_colors.dart, app_theme.dart
  models/         place.dart, event_item.dart, profile.dart
  data/           curated_places.dart
  services/       api_config.dart, events_service.dart, places_service.dart,
                  weather_service.dart, storage_service.dart
  state/          app_state.dart          ← Provider / ChangeNotifier
  screens/        onboarding, home_shell, explore, map, events, saved, profile
  widgets/        brand_mark, place_card, event_card, place_sheet, city_map
assets/data/events.json                 ← offline event fallback
```

**Design**

- Colors: paper `#f5f1ea`, forest `#1e3b35`, gold `#d99f43`
- Fonts: **DM Sans** + **Instrument Serif** (`google_fonts`)
- Bottom nav: Explore · Map · Events · Saved
- Phone-sized type, large tap targets, bottom sheets instead of desktop drawers

**Live data**

- Events: `https://budgetgurugram.vercel.app/api/luma-events`
- Nearby places: `https://budgetgurugram.vercel.app/api/nearby-places`
- Weather: Open-Meteo
- Fallback events: `assets/data/events.json`
- Saved profile: `shared_preferences`

**Map**

- `flutter_map` + OSM raster tiles (`tile.openstreetmap.org`)
- Pins for live places, guide places, events
- User location marker when GPS is used

`dart analyze lib` was clean when the app was first generated.

### Website / backend (already built, do not rebuild unless APIs break)

- `/api/luma-events` — Luma discover API (`gurugram` / `gurgaon`), Meetup Gurgaon, CommunityMeetups. Strict Gurugram city filter. Fitness + AI included.
- `/api/nearby-places` — Geoapify Places API (`GEOAPIFY_API_KEY` on Vercel). Overpass was too unreliable.
- GitHub Actions + Vercel Cron refresh events every 3 hours.
- Optional OpenAI blurbs if `OPENAI_API_KEY` is set.
- Optional Supabase profiles (website only; app does not use it yet).

---

## How to run the app

```bash
cd "/Users/Lenovo/Desktop/Summer 2026/Josh Tech work/budgetgurugramapp"
flutter pub get
flutter run
```

Needs a simulator/device. Location permission strings are already in iOS `Info.plist` and Android `AndroidManifest.xml`.

---

## What can be added next (good work for this chat)

Priority order if the user just says “continue”:

### High impact

1. **Polish on a real phone** — spacing, empty states, loading skeletons, pull-to-refresh everywhere, keyboard-safe search.
2. **Place details** — richer sheet: tags, hours, source link, “open in maps”, save/unsave live nearby pins (not only curated IDs).
3. **Event details screen** — dedicated page, not only an external Luma link. Show fit %, map, date, description.
4. **Better map** — clustering when zoomed out, fly-to on area change, legend, recents.
5. **Copy latest `events.json`** from the website repo into `assets/data/events.json` after each website sync.

### Product features

6. **Voice / ElevenLabs** — “Listen to my day” briefing (hackathon idea; not started in the app).
7. **OpenAI query parser** — “quiet café under 300 near Sector 29”.
8. **Supabase sync** — optional account, same tables as the website (`profiles`, `saved_places`, `saved_events`).
9. **Offline-first cache** — last good nearby + events stored locally.
10. **Notifications** — “event today that matches you”.
11. **Add a place** — user submission form (website had a stub).

### Engineering

12. **Tests** — scoring, Gurugram event filter, onboarding persistence.
13. **App icons + splash** — still default Flutter icons.
14. **Error handling** — timeout / no-network screens that still show curated places.
15. **Config** — move `ApiConfig.baseUrl` if the Vercel URL changes.

---

## Rules for the new app chat

- Work **only** in `budgetgurugramapp` unless the user asks to change the Vercel APIs.
- Keep Flutter. Do not rewrite in React Native / Swift.
- Keep the component split (screens / widgets / services / state). Do not dump everything into `main.dart`.
- Keep the trust model: show source + freshness. Never claim “open now” or “verified prices” without a real source.
- Events must stay **Gurugram-focused**. Do not reintroduce global Luma discover without a city filter.
- Do not invent coordinates. If an event has no real venue, say “Confirm venue on source” instead of a fake km.
- Website header/footer/guides stay out of the app.
- Do not commit or push unless the user asks.

---

## Design tokens (match these)

```
paper      #f5f1ea
cream      #faf8f4
forest     #1e3b35
gold       #d99f43
ink        #1c2624
muted      #74807b
food pin   #ef3340
work pin   #0ea5e9
event pin  #7c3aed
```

Fonts: DM Sans (UI), Instrument Serif (headlines / italics).

---

## Known gaps / gotchas

- Live map pins need `GEOAPIFY_API_KEY` on the **website** Vercel project. If the key is missing, the app should still show curated guide pins.
- Events API can time out on Vercel Hobby (~10s). App already falls back to bundled JSON.
- Website `main` may not include the latest event-scraper work unless it was committed and pushed.
- `flutter_map` uses OSM raster tiles, not MapLibre/OpenFreeMap vector styles. Fine for v1; can upgrade later.
- Saved IDs are strings. Live Geoapify places use different IDs than curated places — saving a live pin may not round-trip until you persist the full place object.
- Default user point is Cyber City: `28.4945, 77.0894`.

---

## One-line pitch

**Gurugram Commons is a phone app that ranks nearby places and public events for Gurugram around what you need today — eat, work, pause, or show up — with sources visible and no website clutter.**
