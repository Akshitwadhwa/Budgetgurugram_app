# Budget Gurugram — Design System

The reasoning behind the interface. Component APIs are in the code; this
document is the *why*, and it is the thing to read before changing anything
visual.

---

## 1. The thesis

Every event app shows you the organiser's own marketing copy. This one shows you
**the gap between what a listing claims and what the thing actually is.**

That single sentence generated every decision below. Where a choice had to be
made between looking impressive and expressing the thesis, the thesis won.

Two consequences follow, and they are the whole system:

> **1. Certainty is a design primitive.** The interface looks more or less sure
> of itself depending on how sure it actually is.
>
> **2. A conclusion is never shown without a route to its sources.** Not as a
> policy — as a type signature.

---

## 2. Certainty as a primitive

Most products treat confidence as a number in a badge. Here it changes the
*fabric* of the surface it appears on.

| Band | Score | Card chrome | Headline | Meter |
|---|---|---|---|---|
| **Likely** | ≥ 0.75 | Solid border, tinted fill | "Likely a workshop" | Solid segments |
| **Possibly** | 0.50 – 0.75 | Solid border, tinted fill | "Possibly a workshop — sources disagree" | **Hatched** segments |
| **Unclear** | < 0.50 | **Dashed border, no fill** | "Format unclear" | Hollow outlines |
| **None** | no verdict | Dashed border, muted | "Not analysed yet" | — |

A dashed border cannot be expressed with `BoxDecoration`, which is why
`DashedBorderPainter` exists. That inconvenience is the point: **a low-confidence
card is a different object, not a recoloured one.** You can identify the band
from across the room, before reading a word.

### Why segments, not a percentage

A percentage invites arithmetic about a number the user cannot audit. "68%" of
what? Five discrete segments read as *how much was found* — which is what the
number actually means, since it is derived from how many sources agreed.

### Four redundant channels

`ConfidenceMeter` encodes the band in **quantity, fill style, colour, and text**
simultaneously. It survives greyscale, every form of colour-blindness, and a
screenshot at thumbnail size. Colour is never the only carrier of meaning
anywhere in this app.

### Unclear is neutral, not red

`ConfidenceBand.unclear` uses the muted grey, deliberately not an error colour.
An honest "we don't know" is a **correct outcome**, and the app will produce it
constantly in a small city with a thin corpus. Colouring it like a failure would
train users to distrust the one state that is always true.

---

## 3. The hero: the claim → reality gap

`VerdictCard` puts the argument on screen as a layout:

```
LISTED AS   M̶e̶e̶t̶u̶p̶          ← mono, greyed, struck through
     ↳
Likely a workshop            ← serif display, full ink
hands-on, bring a laptop
```

Small, mono, struck-through above. Large, serif, confident below. Joined by a
turn arrow. The eye travels *claim → reality* in one movement.

Every other app can show a title and a time. Only one that kept the history can
draw that arrow, so the arrow is the product.

---

## 4. Typography: three faces, three jobs

| Face | Job | Never used for |
|---|---|---|
| **Instrument Serif** | Display, headlines, quotations | UI labels, data |
| **DM Sans** | Anything read as sentences | Metadata |
| **JetBrains Mono** | Labels, timestamps, counts, domains, distances | Prose |

The mono role is doing the heaviest lifting and is the least obvious choice.
**Metadata set in mono reads as *recorded* rather than *written*.** It signals
"this came from a source" without a word of explanation — the typographic
expression of the trust model. `LISTED AS`, `02`, `meetup.com`, `4.2 KM`, and
`STRONG SIGNAL` are all machine-adjacent facts, and they all look it.

Quotations from sources are set in **italic serif**, so cited words are visibly
someone else's before you read them.

The italic serif accent is used **once per screen** — the second half of a
two-part headline ("Make the city / *yours*"). Used sparingly it is a signature;
used everywhere it is noise.

---

## 5. Colour

Warm paper, not cool grey. The product is a briefing document, not a dashboard,
and warmth is what separates it from every other dev-adjacent app.

**Light "Paper"** — `#F4F0E8` canvas, forest `#1E3B35`, gold `#B07D22`.
**Dark "Ink"** — `#11140F`, a warm charcoal with a green undertone, never
blue-black. The paper identity survives the lights going out.

Dark mode is a **real palette, not an inversion**. Both themes are produced by
one function from one `AppPalette`, so they cannot drift apart — a fix in one is
a fix in both. Widgets never reference a hex; they ask for a role
(`context.palette.inkMuted`) via a `ThemeExtension`.

Structure comes from **hairlines, not shadow**. There is almost no elevation in
this app. Rules give sections a visible top edge and make the page read as a
document.

---

## 6. Motion

| Token | Duration | Used for |
|---|---|---|
| `instant` | 110ms | State flips |
| `fast` | 180ms | Chips, pins, toggles |
| `base` | 260ms | Sheets, transitions |
| `slow` | 420ms | Entrance reveals |

Only one curve overshoots (`emphasized`, `easeOutBack`) and it is reserved for
things that *arrive* — sheets, a selected pin. Everything else uses
`easeOutCubic` so the app never feels bouncy.

`Reveal` staggers list items by 45ms, capped at the 7th item so long lists never
make you wait. Screens resolve top to bottom, like a page being set.

Page transitions are **fade-forwards, not zoom**: opening an event should feel
like turning a page, not launching a new context.

---

## 7. States are designed, not defaulted

Most of the craft in this app is in states that a demo never reaches.

- **Skeletons, not spinners.** The page has known structure, so showing that
  structure is more honest than a spinner implying the app has no idea what is
  coming.
- **Empty states carry information.** The Saved empty state explains that your
  list never leaves the device. The events empty state admits Gurugram is a
  small calendar rather than apologising.
- **Refusals look like answers.** In `AskSheet`, "I don't have anything sourced
  on that" is styled exactly like a real answer — same weight, same position, no
  error red. Dressing a refusal as a failure teaches users that "I don't know"
  is a malfunction. It is the correct default.
- **No verdict is its own state**, distinct from a low-confidence verdict.
  "We haven't looked yet" and "we looked and it's murky" are different claims.
- **Unresolved venues never get a distance.** If a venue only geocoded to the
  city centre, the app says "Confirm venue on source" rather than quoting a
  fabricated kilometre figure.

---

## 8. Map

Mapbox tiles through `flutter_map`, **not** the native `mapbox_maps_flutter`
SDK. Reasons, in order:

1. **Markers stay Flutter widgets.** The native SDK renders annotations from
   pre-baked images — a custom marker means shipping PNGs at three densities and
   losing animation, theming and hit-testing. Here a pin is a widget: it
   animates, follows the palette, and switches with dark mode for free.
2. **No native configuration**, no secret download token, no build break the
   morning of a demo.
3. **The styling is identical** — the look people mean by "Mapbox" is the tiles.

Basemap style follows the app theme (`light-v11` / `dark-v11`). The minimal
styles are chosen over `streets` because the basemap should recede: it is a
ground for pins, and near-monochrome lets the category colours carry all the
meaning.

**Pins** (`MapPin`) are drawn, not imported — a squircle with a short tail. A
ring in the surface colour keeps them legible over parks, water and dense
labels. Shadows are offset downward only, so a field of pins floats above the
map rather than embossing into it. Selection **scales and raises** rather than
recolouring, so category colour keeps meaning exactly one thing.

The user's own position is a **pulsing halo** — distinct in *shape*, not just
colour, so you never confuse yourself with a café.

Attribution is rendered unconditionally. It is a licence condition for both
providers, not a decoration.

Without `--dart-define=MAPBOX_TOKEN=…` the app falls back to OpenStreetMap tiles
and keeps working. **A missing key degrades the map's looks, never its
function** — and the Profile screen says which one is live rather than quietly
looking worse.

---

## 9. Where the rules are enforced

Design rules written in a document rot. These are enforced in types and tests:

| Rule | Enforcement |
|---|---|
| A verdict cannot exist without evidence | `assert` in `EventVerdict`'s constructor; `VerdictCard` takes a non-nullable list |
| Confidence language is never unhedged | `headline` is a getter on the model, not a string in a widget — no screen can compose its own claim |
| Band thresholds are defined once | `ConfidenceBand.fromScore`, tested at 0.49 / 0.50 / 0.74 / 0.75 |
| Unclear never names a format as fact | `verdict_test.dart` asserts the word "workshop" is absent from a low-confidence headline |
| Contradiction is never claimed on unclear formats | `contradictsListing` returns false for `EventFormat.unclear`, tested |

`flutter test` — 13 passing. `flutter analyze` — clean.

---

## 10. Token reference

**Spacing** — 4pt base: 2, 4, 6, 8, 12, 16, 20, 24, 32, 40, 56. Page gutter is
20 everywhere, so every screen shares a spine. The gap between 24 and 32 is
deliberate: it is what separates "related" from "a new thought".

**Radii** — sm 8 · md 12 · lg 16 · xl 22 · sheet 28 · pill 999.

**Strokes** — hair 1.0 · edge 1.5 · heavy 2.0. Since hairlines carry the
structure, the difference between `hair` and `edge` is real hierarchy, and
`edge` marks selection.

---

## 11. What is deliberately not here

- **No gradients, no glassmorphism, no glow.** The aesthetic is print. Every
  effect that says "app" instead of "document" was rejected.
- **No illustrations in empty states.** A sentence that tells you something true
  beats a drawing of a cactus.
- **No shadow-based depth.** One elevation level, hairlines for everything else.
- **No percentage on the confidence meter.** See §2.
- **No red for uncertainty.** See §2.
