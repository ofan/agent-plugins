# Motion Design — Techniques Reference

Distilled from damkin (@damkina7), "Autonomous Motion Studio" (X article, 2026-10-07), in our own words. Load when implementing a scene, not for every trigger.

## Spring physics (closed form)

Hero motion uses a damped harmonic oscillator in closed form, so position is a pure
function of t (fits the seek(t) rule — no integration, no accumulated state):

```
x(t) = 1 − e^(−ζωt) · ( cos(ωd·t) + (ζω/ωd) · sin(ωd·t) )
ωd   = ω · sqrt(1 − ζ²)
```

- ζ (damping ratio): ~0.22–0.30 gives roughly 2% overshoot — the Apple/Linear/Stripe feel. ζ ≥ 1 = no overshoot (use for fades of dense text).
- ω (natural frequency): higher = snappier. Start ω ≈ 10–14 rad/s for UI elements.
- Apply per property (translate, scale, opacity via a separate faster curve). Stagger elements by offsetting t, never by timers.
- Every animated value in a scene must be expressible this way (or as a keyframed pure function of t). If a value needs simulation state, restructure it.

## seek(t) scene skeleton

```js
// Pure: same t in -> same pixels out. No clocks, no timers, no unseeded random.
function seek(t) {
  // t in seconds. Compute every element's state from t, draw, return.
}
```

Render loop (Route B): for each frame i, t = i / FPS, call seek(t), wait for paint,
screenshot → PNG sequence → `ffmpeg -framerate <fps> -i frames/%05d.png render.mp4`.

## Audio: frame-synced synthesis

- Beat grid: pick a tempo and lock cues to it. At 120 BPM there are 2 beats/sec, so
  1 beat = 30 frames at 60 FPS (15 at 30 FPS). UI events land on beats or half-beats.
- Synthesize, don't source stock SFX: a UI click is a short decaying sine burst
  (~1800 Hz, exponential decay, tens of ms); a swoosh is filtered noise with a rising
  envelope; a bass drop is a low sine with a pitch fall. Generate in Node/Web Audio
  or with ffmpeg `sine`/`anoisesrc` filters.
- One cue sheet (JSON) is the single source of truth:

```json
{ "fps": 60, "bpm": 120,
  "cues": [ { "frame": 90, "visual": "card-magnetize", "audio": "click" },
            { "frame": 240, "visual": "dashboard-in", "audio": "swoosh" } ] }
```

Both the scene renderer and the audio renderer read this file. Timings cannot drift.

## Storyboard pattern (15s concept demo)

1. Beat 1 (~0–3s): the problem state, one short line of text ("Scattered data.")
2. Beat 2 (~3–7s): transformation — elements move with spring physics toward order (e.g. a cursor pulls scattered cards into place).
3. Beat 3 (~7–12s): the resolved product view, one line ("One clear view.")
4. Beat 4 (~12–15s): CTA on the product's own branding.

Scale beat proportions, not counts, for other durations.

## Critique loop rubric

Extract frames at ~10%, 27%, 57%, 93% of duration. Score each 1–10 on:
- **Typographic contrast** — hierarchy reads at a glance; no text under ~4.5:1 contrast.
- **Inertia** — motion decelerates like a physical object (spring curve), no abrupt stops or linear slides.
- **Polish** — alignment, consistent radius/padding from the token set, no placeholder anything.

<8 on any axis → patch the code (not the frame) → re-render → re-score the same checkpoints.

## Production routes

- **A — Code-drawn**: pure HTML5/Canvas/SVG. Best for diagrams, data stories, abstract explainers.
- **B — Remotion**: full product/UI reels; React components are the UI. Default route.
- **C — Mixed**: generated or shot character/scene video + code UI composited over it.
- **D — Diffusion only**: abstract backgrounds/textures. Never UI, never text, never the product.

## Anti-patterns (from the article's failure analysis)

- **Brief contagion**: styling from prose adjectives ("modern, clean") instead of tokens pulled from a real screenshot. Output looks generic no matter how good the motion is.
- **Timer-driven animation**: setTimeout/rAF chains make frames non-reproducible and capture jittery.
- **Ease defaults**: CSS ease-in-out reads cheap next to spring physics on the same elements.
- **Audio as an afterthought**: cues placed by ear after rendering drift off the visual events. Cue sheet first.
