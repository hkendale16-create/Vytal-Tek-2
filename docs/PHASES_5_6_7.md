# Phases 5–7

## Phase 5 — 3D Experience
- `LiveBodyStage`: perspective yaw/pitch, breath pulse, ambient spin tied to monitoring motion level
- Wearable ring glyph on the figure
- Floating HUD metrics unchanged (no invented vitals)
- Animations respect reduced-motion / dispose with the route

## Phase 6 — AI Coach (Coach Vital)
- Local grounded chat engine — never invents wearable readings
- Refuses diagnosis / prescription style requests
- Uses profile mode + verified health snapshot + note snippets
- Basic vs advanced (`ai.basic` / `ai.advanced`) gating
- Chat history persisted locally

## Phase 7 — Notes & Reminders
- Local notes + reminders (SharedPreferences)
- Notes explicitly labeled as user-entered (not sensors)
- Coach Vital can reference recent note snippets
- Routes: `/notes`, `/reminders` from Profile
