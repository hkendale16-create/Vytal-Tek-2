# Vytal Tek — Design Reference Notes

**Source:** transcript `/tmp/cursor/cloud-agent-transcripts/2026-08-17T01-49-52Z-63fc/bc-01a00c65-23b6-740d-a130-152538f942e5/transcript.json`

**Finding:** Latest design-mockup user turn is `messages[913]` (`{"role":"user"}` only). Three design boards were uploaded in that turn, but the transcript store does **not** include image URLs, base64, file paths, `imageDescription`, or `mediaImage` payloads. No PNG/JPEG/WebP magic bytes and no `data:image` strings exist in the transcript JSON.

Vision-derived details below come from the parent agent’s extraction of those three inline board descriptions (assistant thinking at `messages[930]`), merged with the approved visual system from the master implementation prompt (`messages[0]`).

**Images not saved:** Could not write `01-ecosystem-dark.png`, `02-light-dark-board.png`, or `03-brand-identity.png` — pixel data was not present in the transcript.

---

## Board mapping (inferred from descriptions)

| Intended file | Board content |
|---|---|
| `01-ecosystem-dark.png` | Dark-mode product ecosystem: landing + desktop body + mobile screens |
| `02-light-dark-board.png` | Light/dark theme comparison and soft teal light surfaces |
| `03-brand-identity.png` | Logo, wordmark, tagline, app icon variants |

---

## 03 — Brand identity

### Logo
- Stylized glowing **“V”** mark with a **circular dot** accent
- Premium, futuristic, luminous — not a flat geometric monogram alone

### Wordmark
- **VYTAL** and **TEK** as split wordmark with **divider lines**
- Treat brand/wordmark as a hero-level signal on branded surfaces

### Tagline
- **LIVE BETTER. BECOME STRONGER. EVERY DAY.**

### Landing / marketing headline (from boards)
- **Live Health. Real Feedback. Stronger You.**
- Paired with a **3D smart ring** hero and primary CTAs
- Device is the visual focus; do not cover the hero with stat overlays

### App icons
- Dark and light teal **V** variants

---

## 02 — Color & theme (light / dark board)

### Shared brand palette
- Electric **cyan** and **teal** as primary accents
- Restrained green; small violet/purple where useful (especially sleep)
- Same brand identity in both themes — do not invent separate looks

### Dark mode (dominant aesthetic on boards)
- Deep **black / navy / charcoal** (prefer deep navy/charcoal over pure black per master prompt)
- Neon teal and cyan glows
- Soft gradients
- **Glassmorphism** cards
- Subtle glow on interactive/health elements

### Light mode
- **Off-white / soft gray / light gray** surfaces
- Softer teal accents and softer glow
- Subtle glass effects and soft shadows

### Theme modes to support
- Light
- Dark
- Follow System

### Product feel (master prompt)
- Futuristic, minimalist, premium, intelligent, responsive, alive, calm
- Avoid overwhelming sci-fi clutter; motion should communicate information

---

## 01 — Ecosystem / product UI (dark board emphasis)

### Desktop / large body experience
- Central **3D holographic human figure**
- Floating metric cards around the body:
  - Heart rate
  - SpO2
  - Temperature
  - Sleep
  - Activity
- Cards stay around the model; do not cover the 3D figure with dense stats
- Body slowly breathes/moves; supports rotation; reflects health visually (e.g. pulse at chest)

### Mobile screens shown on boards
1. **Dashboard / Home** — circular **readiness gauge** + step widgets + floating metric widgets
2. **Activity** — calorie charts / rings, workout-oriented visuals
3. **Sleep** — purple/blue accents, sleep score, stage breakdown; calmer motion than daytime
4. **3D body view** — mobile-friendly body silhouette with floating cards
5. **AI coach chat** — labeled **“Coach Vital”** (chat interface)

### Bottom navigation (from mockups — authoritative for UI labels)
1. **Home**
2. **Activity**
3. **Sleep**
4. **Insights**
5. **Profile**

Suggested route remap vs earlier scaffold:
- Home → Today
- Activity → Activity
- Sleep → Sleep (dedicated)
- Insights → Analytics
- Profile → Settings
- Body + AI Coach remain accessible from Home / Insights (not necessarily all in bottom nav)

### Master-prompt primary experiences (architecture, not all in bottom bar)
- Home / Today, Analytics, Activity, Body, AI Coach, Devices, Profile / Settings
- Do not overload bottom navigation

---

## Screen layout rules (from boards + master prompt)

### Home / Today
Answers “How am I doing today?” quickly:
- Personalized greeting
- Prominent readiness score/status
- Floating HUD-style health metrics
- Device state + monitoring mode
- AI insight
- Quick activity access
- Battery when relevant

### Readiness
- Large central score
- Surrounding floating cards (HR, HRV, Sleep, Recovery, Energy)
- Extremely subtle float motion
- Explain contributing factors in plain language (non-medical)

### Activity
- Duration, HR / zones, distance, calories, steps, load, summary
- Activity-responsive animation (reduce/pause on background / battery saver)

### Sleep
- Score, duration, bedtime/wake, stages, HRV/RHR where available
- Slower floating motion; calmer purple/blue palette accents
- Floating visual language preserved

### Analytics / Insights
- Ranges: 7d / 30d / 90d / 1y
- Trends for HR, HRV, sleep, load, activity, recovery, SpO₂, temperature, etc.
- Smooth charts; prefer aggregated data

### AI Coach (“Coach Vital” / Ask Vytal)
- Grounded in the user’s own data; not a generic chatbot
- Natural-language Q&A; admit missing data
- Entry via nav, contextual cards, or dedicated chat screen

---

## Motion principles
- Level 1 Micro — buttons, cards, values
- Level 2 Health response — pulse, metric transitions
- Level 3 Ambient — waves, particles, device rotation
- Level 4 3D — device + body models
- Pause/reduce when backgrounded, not visible, battery saver, or Reduce Motion

---

## Implementation note
Until the original PNG/JPG boards are committed to this folder as:

- `/workspace/docs/design/01-ecosystem-dark.png`
- `/workspace/docs/design/02-light-dark-board.png`
- `/workspace/docs/design/03-brand-identity.png`

…treat this document as the working visual contract derived from the uploaded boards’ descriptions.
