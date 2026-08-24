# Burst 0.2.2

Burst is a manual magic-burst advisor and optional skillchain coach for **retail FFXI on Ashita v4**. It observes incoming combat data, recommends an action, and leaves every spell, weaponskill, target choice, and equipment change to the player.

The interface and settings workflow are based on the current **Warn 2.2.0** interaction model: a three-tab tactical dashboard, draggable launcher, responsive scale presets, live positioning preview, configurable appearance, custom WAV discovery/testing, persistent exact-name choices, controller navigation, and a diagnostics page. The combat card, timer, launcher, and outer dashboard shell use a bespoke dark-navy and double-brass ornamental treatment inspired by classic fantasy UI frames.

## Install

1. Extract the `burst` folder into `Ashita/addons/`.
2. In game, run `/addon load burst`.
3. Run `/burst` or click the draggable **B** launcher.
4. Open **Options → Diagnostics** and run the synthetic self-tests.
5. Use **Burst Coach → Test Fragmentation** to position and preview the combat card before fighting.

Settings are stored by Ashita under `config/addons/burst` and survive reloads.
Advisor and timing choices can be kept in exact character/main-job profiles; appearance and sound remain shared interface preferences.

## Commands

| Command | Result |
|---|---|
| `/burst` | Open or close the dashboard |
| `/burst on` | Enable magic-burst advice |
| `/burst off` | Disable magic-burst advice |
| `/burst test` | Show a safe synthetic Fragmentation preview |
| `/burst plan` | Open Skillchain Assist |
| `/burst debug` | Toggle concise recognized-event chat diagnostics |
| `/burst clear` | Clear current combat and coach state |

No command casts a spell or uses an ability.

## Burst Coach

After a confirmed skillchain on a valid loaded enemy, Burst:

- Reads every target and action in incoming `0x028` packets.
- Deduplicates rapid duplicate action packets.
- Tracks confirmed chains separately by target server ID.
- Limits recognized actors to the player’s alliance, party members, Trusts, and detected party pets.
- Resolves burst elements for level 1–4 retail skillchains.
- Checks the current main/subjob, level, learned spell, MP reserve, recast, player status, enemy target, range, and estimated landing time.
- Checks the equipped Blue Magic set and requires Burst Affinity or Azure Lore for Blue Magic recommendations.
- Shows one recommendation and no more than two alternates.
- Prefers a faster spell when a stronger spell would land too late.
- Confirms a manually cast magic burst from its result packet.
- Labels every live result as `SKILL CHAIN:` and displays all valid burst elements as color-coded capsules.
- Adds the supplied elemental icons beside their names in the combat card and uses smaller contextual icons in the coach, planner, and selected-spell detail views.
- Preserves text labels and color coding so elemental guidance remains understandable without relying on icon recognition alone.
- Shows `WINDOW CLOSED` for 0.5 seconds by default, then dismisses the combat card.

The default target policy is **Current Target Only**. This prevents a chain elsewhere in a crowded fight from telling you to cast on the wrong enemy.

### Timing calibration

Retail resource cast time is interpreted as `CastTime / 4`. Burst then applies the configured Fast Cast estimate, latency allowance, and safety margin. Start with conservative values and tune them against live play:

- Fast Cast Estimate: your normal casting-set estimate.
- Latency Allowance: observed client/network overhead.
- Safety Margin: how early a spell must be expected to land.
- Burst Window: the server window you want the coach to treat as usable.

## Optional Skillchain Assist

Skillchain Assist is **Off by default**.

| Mode | Behavior |
|---|---|
| Off | Only Burst Coach runs |
| Planner | Builds two-step plans without live prompts |
| Coach | Shows opener, `WAIT`, and `GO` instructions |
| Adaptive Coach | Replans a compatible closer after an unexpected recognized step |

Choose the mage, goal, local-player participation, and any configured party profiles. Local weaponskill availability is read exactly. Remote player capabilities are used only when you enter them as a comma-separated list.

Plans can optimize for:

- The best available two-step property.
- A preferred spell or element for the selected mage.
- A specific skillchain.
- Light or Darkness.
- A simple fastest two-step route.

The coach only reacts to confirmed actions. Unexpected steps in Adaptive Coach mode are resolved against configured available closers; if a valid recovery exists, the overlay updates the closer and expected result.

## Appearance, themes, and sound

- Use **Options → Appearance** for scale presets, card opacity/scale, edge intensity, reduced motion, alternates, controller layout, and the live draggable positioning preview.
- The element-colored screen-edge cue is enabled by default and activates for every confirmed skillchain, including blocked recommendations. Use **Test Edge Cue** to preview it safely.
- Use **Options → Timing → Post-Window Linger** to change the default 0.5-second dismissal hold.
- Packaged themes live under `burst/themes/<name>/theme.txt`.
- Per-user themes can be placed under `Ashita/config/addons/burst/themes/<name>/theme.txt`.
- Put standard `.wav` files in `burst/sounds`, then use **Options → Sound → Refresh Sounds**. File choices are exact-name persisted and can be tested in place.
- Element icons live under `burst/assets/elements`. If a texture cannot load on a particular Ashita build, Burst automatically retains its text-and-color presentation.
- The draggable launcher uses the supplied Burst `B` artwork inside the tactical brass frame. Themes may override it with `launcher.png` in their theme folder; if it cannot load, the original text `B` remains as a fallback.

## Safety boundary

Burst has no outgoing packet handler and contains no gameplay command injection. It does not:

- Cast spells or use weaponskills/job abilities.
- Select or change targets.
- Change equipment.
- Queue, retry, delay, or schedule combat actions.
- Send repeated party instructions.
- Control another client, Trust, pet, or LuAshitacast.

The player must deliberately perform every action through their normal macro, hotbar, or command.

## First live validation

This initial release is statically validated, but retail packet behavior still needs an in-game pass on Siren. Keep **Action Packet Layout** on `Auto Detect` first. Test player, Trust, and pet-created Fragmentation/Distortion plus Light/Darkness. The Diagnostics page records parsed packets, duplicates, ignored actors, parse errors, confirmed chains, and confirmed bursts without exposing raw packet data.

If Auto Detect does not recognize your retail packets, switch Diagnostics to `Retail / XiPackets`, reproduce one chain, and report the counters and last-event line.
