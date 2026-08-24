# Changelog

## 1.0.0 — 2026-08-24

- Added the passive Record Breaker easter egg, enabled by default, with one persistent all-time single-damage record per character.
- Added exact local-actor packet validation and a damage-result whitelist that excludes counters, retaliation, spikes, drains, skillchain-only results, status ticks, damage taken, and other actors.
- Added a compact gold personal-best notification and one local chat message when a record increases.
- Added an independent Record Breaker WAV selector and test button under Options → Sound.
- Set `celebrate.wav` as the default Record Breaker sound while preserving it as a selectable configured filename when the user has not copied the file into `burst\sounds` yet.
- Promoted Burst to version 1.0.0 and retained `Sigman` as the addon author.

## 0.2.6 — 2026-08-24

- Added `Center Horizontally`, `Center Vertically`, and `Center Both` layout buttons for the live notification card.
- Made centering use the current game resolution, interface scale, and Burst Card Scale so the complete card is centered accurately.
- Kept single-axis centering independent: horizontal preserves Y, vertical preserves X, while all layout results are clamped on-screen and saved immediately.
- Corrected `Reset Card Position` to use the same scale-aware geometry as the actual rendered card.

## 0.2.5 — 2026-08-24

- Added advisory-only target elemental-weakness scoring with a default-on `+100` ranking bonus; explicit preferred elements remain stronger at `+120`.
- Added case-insensitive, schema-validated named overrides from optional `Ashita/config/addons/burst/weaknesses.lua` with safe missing-file behavior and manual reload support.
- Added a sparse verified numeric-race/model data layer without guessing ecosystem mappings that Ashita does not expose directly.
- Added numeric Race and Look-field diagnostics for live mapping validation, detailed override warnings, synthetic self-tests, and a `Test Weakness` card preview.
- Added restrained live-card weakness highlighting, `★ WEAK` recommendation tags, and a centered target-weakness icon row in the Burst Coach.
- Preserved empty weakness lists as explicit overrides that suppress lower-priority fallback data.

## 0.2.4 — 2026-08-24

- Centered the `SKILL CHAIN:` heading and property inside a dedicated title plaque below the ornamental border.
- Preserved the target name at the right side of the header with collision-aware truncation.
- Centered the complete `BURST ELEMENTS` label-and-icon group as one responsive row.
- Centered the primary recommendation and secondary `CAST NOW` message inside the action area without overlapping the timer plaque.
- Simplified the draggable launcher by removing its ornamental backing accents and framing the supplied logo with one clean gold border.

## 0.2.3 — 2026-08-24

- Fixed the launcher artwork rendering as a solid white rectangle in Ashita v4.
- Converted Direct3D texture pointers to the numeric 32-bit texture IDs required by Ashita's ImGui binding.
- Applied the same correction to all eight elemental icons before they are displayed.

## 0.2.2 — 2026-08-23

- Replaced the generated circular `B` medallion with the user-supplied Burst logo artwork.
- Reshaped the launcher into a compact ornamental plaque so the square logo fits without cropping.
- Added guarded launcher texture loading, explicit unload cleanup, theme override support, Diagnostics status, and the original text `B` fallback.

## 0.2.1 — 2026-08-23

- Added the eight user-supplied Wind, Fire, Water, Ice, Lightning, Light, Dark, and Earth icons as individual PNG assets.
- Added icon-plus-name burst-element capsules to the live notification card.
- Added smaller contextual icons to the Burst Coach, preferred-spell resolution, planner result, and selected-spell detail views without filling dense lists with repeated artwork.
- Added guarded Direct3D texture loading, explicit unload cleanup, and text/color fallback behavior for incompatible or missing textures.
- Added icon-load status to Diagnostics and compact scaling for four-element Light, Darkness, Radiance, and Umbra rows.

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
