# Changelog

## 0.2.0 — 2026-08-23

- Redesigned the notification card around a dark-navy, double-line brass frame with chamfered corners and cardinal diamond ornaments.
- Reworked burst-element capsules, the timer plaque, and the remaining-time track with matching beveled geometry.
- Changed the combat-card heading to the requested `SKILL CHAIN:` wording.
- Restyled the draggable launcher as a double-ring ornamental medallion and carried the frame language into the dashboard shell.
- Preserved conventional controls inside dense settings panels for readability.
- Corrected the 0.1.4 decoder regression: valid skillchain messages now validate the event, while the adjacent 10-bit effect/animation field determines Light, Fusion, Fragmentation, and every other property.
- Added regression coverage proving that different valid message variants cannot override the encoded property.

## 0.1.4 — 2026-08-23

- Changed retail skillchain decoding to use added-effect message IDs. This interpretation was superseded and corrected in 0.2.0.
- Added the complete retail result-message set for level 1–4 skillchains, including alternate Impaction message `398`.
- Confirmed Burst Affinity (`165`), Azure Lore (`163`), and Silent Storm's Wind candidate path.

## 0.1.3 — 2026-08-23

- Removed Burst's redundant successful-load chat message.
- Startup diagnostics now remain silent when they pass and print only when a check fails.
- Ashita's own `[Addons]` load and unload confirmations are unchanged.

## 0.1.2 — 2026-08-23

- Fixed the first burst-element capsule overlapping the `BURST ELEMENTS` label.
- Sized and positioned element capsules from the active ImGui font metrics, with guarded compatibility fallbacks.
- Reserved a dedicated action-text column so explanations cannot draw underneath the timer badge.
- Enlarged and centered the timer badge contents so `REMAINING` stays inside its border.
- Shortened the no-learned-spell explanation while preserving its meaning.

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
