# Changelog

## 0.1.1 — 2026-08-23

- Reduced the default post-window card linger to 0.5 seconds and added a Timing setting for it.
- Added a brief `WINDOW CLOSED` state instead of leaving an expired recommendation at `0.0s`.
- Added explicit `SKILLCHAIN:` labeling and color-coded capsules for every valid burst element.
- Rebuilt the live card with a framed action panel, dedicated timer badge, thicker timing bar, and clearer ready, urgent, blocked, success, and closed states.
- Removed duplicate blocked-state wording and added a clearer `NO MATCHING SPELL LEARNED` explanation.
- Made the screen-edge cue activate for every confirmed skillchain, including blocked recommendations.
- Increased the new-install edge intensity default to 0.72 and added an Appearance test button.

## 0.1.0 — 2026-08-23

- Added read-only retail/legacy `0x028` action-packet parsing with all-target/all-action traversal.
- Added packet deduplication, alliance/Trust/pet actor filtering, per-target chain state, lifecycle clearing, and burst confirmation.
- Added job-, spellbook-, BLU-set-, MP-, recast-, status-, target-, range-, and timing-aware spell recommendations.
- Added more than 100 runtime-validated elemental, helix, ninjutsu, divine, dark, and magical Blue Magic candidates.
- Added optional two-step Skillchain Planner, live Coach, and adaptive recovery behavior.
- Added Warn 2.2.0-style dashboard, launcher, responsive scaling, tactical theme, draggable live preview, edge cues, sound discovery/testing, persistence, controller navigation, and diagnostics.
- Added explicit advice-only automation boundary and static source checks.
