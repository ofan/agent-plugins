---
name: motion-design
description: Design and render motion graphics and product/UI videos from deterministic code: seek(t) scenes, closed-form spring physics, frame-synced synthesized audio, and a screenshot critique loop. Use for a product reel, promo video, UI animation, explainer video, motion design, or an animated demo of an app or interface.
---

# Motion Design

Methodology distilled from damkin (@damkina7), "Autonomous Motion Studio" (X article, 2026-10-07). Detail in `references/techniques.md` next to this file.

## Purpose
Produce agency-grade motion pieces — product reels, UI demos, explainers — by writing a program that renders the video, never by prompting a diffusion video model for UI/product content. The model writes code; a headless browser renders frames; ffmpeg compiles them.

## Core Rule: seek(t)
Animation is a pure function of time. Frame = f(t). Every visual state is derivable from the timestamp alone.
- BANNED inside a scene: `setTimeout`, `setInterval`, stateful `requestAnimationFrame` accumulation, wall-clock reads, randomness without a fixed seed.
- Any frame must be reproducible by seeking directly to it. If a frame cannot be rendered cold, the scene is wrong.
- Capture waits for paint completion, then steps t. Fixed FPS (30 or 60), zero jitter.

## Stack
- Default: Remotion (React + TypeScript + Tailwind + Lucide icons + system fonts). Scaffold with `npx create-video@latest <project>`; render with the Remotion CLI.
- Light pieces: a single HTML5 Canvas/SVG page driven by a `seek(t)` function, rendered frame-by-frame with Playwright screenshots, compiled with ffmpeg.
- Mixed: generated/shot video for characters or scenes, code-rendered UI layers composited on top.
- Diffusion video ONLY for abstract backgrounds. Never for UI, text, or product shots.

## Workflow
Gates, in order. Do not skip ahead.
1. **Brief** — one line: audience, message, duration, aspect (16:9, 9:16, or 1:1), CTA.
2. **Storyboard** — beat list with timestamps. A 15s piece is ~4 beats: problem → transformation → result → CTA.
3. **Design tokens** — anchor styling to a REAL screenshot of the product/UI: exact hex colors, border radius, padding, font. Never invent styling from a prose description (generic briefs produce generic output).
4. **Wireframe** — static layout per beat, tokens applied.
5. **Motion** — implement scenes as seek(t). All hero motion uses closed-form spring physics (see references). No linear easing, no default CSS ease-in-out on hero elements.
6. **Audio** — frame-synced cues on a beat grid; synthesize clicks/swooshes/bass in code. One JSON cue sheet drives both visual events and audio cues so they cannot drift.
7. **Critique loop** — render, extract checkpoint frames (~10%, 27%, 57%, 93% of duration), audit each: typographic contrast, motion inertia, overall polish (1–10). Any score <8 gets a code patch and a re-render. 2–3 iterations max unless asked for more.
8. **Final** — verify acceptance criteria, then deliver the mp4.

## Output Contract
- `render.mp4` on disk in the project dir; duration verified with `ffprobe` against the brief.
- If a loop was requested, first and last frames must match (seamless loop, checked by frame diff).
- No placeholder assets, no lorem ipsum in UI, no stock text.
- Deliver: the mp4, plus one line each for duration/format, the critique scores, and what remains unverified.

## Operating Rules
1. Directory fencing per project: `sources/` (inputs, screenshots), `drafts/` (renders under critique), `published/` (accepted finals). Never overwrite a published file.
2. Determinism is testable: re-rendering the same scene at the same t must produce byte-identical frames. Check before the critique loop.
3. Text in UI comes from the product or the brief, verbatim. Never paraphrase a product's labels.
4. Report rendered facts only: duration, resolution, FPS, file size, critique scores. Cost/time claims from the source article are the author's marketing, not verified numbers — never repeat them as measured results.
