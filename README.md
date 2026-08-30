# Gurugram Commons (Flutter)

Mobile app for the BudgetGurugram / Gurugram Commons guide.

## Features

- 3-step onboarding (motive, role, location)
- Explore recommendations, search and filters
- Map with live nearby pins + curated guide pins
- Gurugram events from the existing Vercel API
- Saved places stored on device
- Weather-aware context

Website chrome (header, footer, guides) is removed. Navigation is a bottom bar: Explore, Map, Events, Saved.

## Run

```bash
cd budgetgurugramapp
flutter pub get
flutter run
```

The app reads live data from `https://budgetgurugram.vercel.app` and falls back to `assets/data/events.json` if the events API is unreachable.
