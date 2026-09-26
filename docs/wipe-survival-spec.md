# WIPE: SURVIVAL — Spec

One document. It replaces the recruiting prototype spec (complete, signed off
2026-09-25; this tree is its result) and the separate MVP and V1 specs. Scope
discipline lives in the milestones at the end, not in document boundaries.

---

## 1. Identity

WIPE is Geometry Wars' feel on Vampire Survivors' loop.

Geometry Wars is a skill test with a wow factor, and a skill test with no
growth curve exhausts itself in an hour. Vampire Survivors is a growth curve:
the run itself grows, and every run feeds a permanent curve between runs. WIPE
keeps the first game's responsiveness, readability, and luminous chaos, and
builds the second game's loop under it.

The addiction is not one mechanic. It is three curves that overlap so that
one is always rising:

1. Power within the run: level-ups, weapons, passives, evolutions.
2. Progress between runs: gold banked from every run, a shop of permanent
   power-ups, an unlock list.
3. A collection that is never complete: weapons, ships, evolutions, stages.

Desired reactions, in order:

> "Okay, this already works — and it has some punch."
> "I almost made it to 18 minutes. One more."
> "This is built in With??"

### Pillars

- **Instant.** Launch into gameplay in under 3 seconds. No menus before the
  first run. Death to next run in under 2 seconds.
- **Responsive.** Twin-stick movement and aiming, auto-fire, fixed-step
  simulation, no perceived input latency.
- **Readable under chaos.** Gameplay silhouettes stay solid; effects are
  transient; the player, enemies, drops, and bullets are distinguishable at a
  glance at any entity count.
- **Growth every minute.** Something gets stronger, unlocks, or fills at
  least once a minute of play.
- **Every run pays.** Gold is banked whatever happens. No run is wasted.

---

## 2. Baseline

The prototype in this tree already provides, verified:

- twin-stick movement and independent aim on keyboard, mouse, Xbox
  controller, and Steam Controller over its USB puck through SDL3
- auto-fire, one-hit kills, contact damage, invulnerability, instant restart
- four chaser silhouettes sharing one behavior
- kill score with a decaying multiplier and floating score popups
- the visual layer: warping blue lattice, two-tier bloom, line-spark
  explosions, shake, hit-stop, spawn rings
- ambient-house music surviving retry, five effect cues
- pooled entities at 120 Hz, 60 fps at 512 enemies plus saturated particles
- debug overlay, acceptance harness, deterministic simulation tests

Everything below builds on that. Nothing below removes any of it.

---

## 3. Controls and Platform

Steam Deck first; desktop is the development platform.

| Action | Keyboard / mouse | Controller |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Aim | Mouse | Right stick |
| Fire | Automatic | Automatic |
| Choose upgrade | Mouse / 1-2-3 | D-pad or stick + A |
| Retry, confirm | Space | A |
| Shop, unlocks | Click | A / B |
| Quit | Escape | — |

Requirements: radial deadzone on both sticks, centered aim retains the last
direction, mouse movement takes aim back from the pad, gameplay input ignored
while unfocused. Xbox and Steam Controller are mandatory and validated on
hardware; Steam Deck speakers and controls are validated before release.

No dash. No manual fire. No rebinding UI.

---

## 4. The Run

### Length and end

A run lasts up to **20 minutes**. The cap is load-bearing: it makes a run a
unit of effort with a finish line, so "one more run" has a known cost. Tune
the cap between 15 and 30 minutes only with playtest data.

A run ends when the player dies or when the timer reaches the cap. At the
cap, an unkillable Reaper enters and ends the run within seconds; surviving
to the cap counts as a clear.

### Timeline

Difficulty is a minute-by-minute spawn timeline, not a wave counter:

| Minutes | What happens |
|---|---|
| 0–2 | Chasers only, thin. First level-up within 30 seconds. |
| 2–5 | Density rises. Darts appear. First elite at 3:00. |
| 5–10 | Spinners and Weavers join. Elites every minute. Boss at 5:00 and 10:00. |
| 10–15 | Full roster, walls of enemies, second and third evolutions become reachable. |
| 15–20 | Screen-filling density. Boss at 15:00. Reaper at 20:00. |

Every enemy kind, elite, and boss has a first-appearance minute in a data
table. The table is tuning, not architecture, and lives with the other
knobs.

### Pacing beats

- **Elites**: one larger, tougher enemy of an existing kind, marked
  visually, dropping a guaranteed chest.
- **Bosses**: at 5, 10, and 15 minutes. A boss is a screen-clear gate with a
  telegraphed pattern and a health bar, the one enemy health bar in the game.
- **Chests**: dropped by elites and bosses. Opening a chest grants one to
  three upgrades at once, or an evolution if one is available. This is where
  the run's power spikes.
- **Breathers**: after a boss dies, five seconds of thinned spawns and a
  music lift.

### Death

Death is instant and loud: the largest burst in the game, a radial
shockwave, strong brief shake, a flash, 100–150 ms freeze, then the results
screen within half a second. No lengthy animation.

---

## 5. Feel

The visual and audio direction is fixed by the prototype and stays:
luminous wireframes on a deforming electric-blue lattice, controlled bloom
with sharp silhouettes, white-hot bullet cores with gold trails, saturated
lime, cyan, magenta, and blue, directional spark bursts, ambient-house music
with a steady pulse.

Juice is required scope, not polish:

- **Shots**: bright core, trail, muzzle flash, small firing impulse.
- **Hits**: 30–60 ms flash, scale punch, a few impact sparks, tiny knockback.
- **Kills**: 8–20 line sparks inheriting impact direction, expanding ring,
  silhouette scale-out, kill sound, light shake scaled by combo.
- **Level-up**: brief freeze, a pulse from the ship, a rising chime.
- **Evolution**: the loudest non-death moment: freeze, screen flash, a named
  banner, the new weapon's first volley.
- **Boss entry**: red edge warning for 1.5 seconds, WARNING text, spawns
  pause, 120–150 ms freeze, camera zoom out, music shift.
- **Boss kill**: 200–350 ms freeze, explosion cascade, all enemies die, gold
  flash, the strongest shake.
- **Player hit**: strong flash, edge vignette, 30–60 ms hit-stop, flicker.

Effects never obscure enemy silhouettes or the player. Readability is
measured at the 15-minute density, not the first minute.

---

## 6. Player Growth Within the Run

### XP gems

Every kill drops a gem. Gems are collected by proximity, with a magnet radius
that is a stat. Gems do double duty, which is where the two games meet:

- collecting fills the level-up bar
- collecting extends the combo; the combo decays after about two seconds
  without a gem, resets on damage, and multiplies gold earned

Uncollected gems merge into larger gems after a few seconds so the floor
never fills with clutter, and a rare vacuum pickup collects every gem on
screen.

### Level-ups

The level-up bar fills with XP; the XP needed per level grows so that early
levels come every 30 seconds and late levels every one to two minutes. On
level-up the game pauses and offers a choice of three (four with a luck
passive):

- a new weapon, if a weapon slot is free
- an upgrade to an owned weapon (up to level 8)
- a new passive, if a passive slot is free
- an upgrade to an owned passive (up to level 5)

Skip and reroll exist as shop-bought permanent counts, one per run each at
first. Choosing resumes play immediately.

### Weapons

Six weapon slots. Every weapon fires automatically; the player never manages
fire. The base weapon is the aimed cannon: bullets follow the aim exactly.
Others fire on their own logic, so the aim stick stays about the cannon.

Launch roster, eight weapons:

| Weapon | Behavior |
|---|---|
| Cannon | Aimed. More projectiles and rate with levels. The one aimed weapon. |
| Orbit | Blades circle the ship. Count and radius with levels. |
| Nova | Periodic ring burst around the ship. |
| Seeker | Homing bolts at the nearest enemy. |
| Lance | Piercing beam in the movement direction. |
| Mines | Dropped on the path, detonating on contact. |
| Arc | Chain lightning between nearby enemies. |
| Shard | Bouncing fragments that ricochet off arena walls. |

### Passives

Six passive slots. Launch roster, eight passives: damage, fire rate,
projectile count, area, projectile speed, magnet, move speed, max health.
Plus cooldown, armor, luck, and gold gain as unlockables.

### Evolutions

A weapon at max level plus its paired passive at any level, then the next
chest, evolves the weapon into a named, visually distinct, much stronger
form. Evolutions are the late-run hook and the collection's centerpiece.
Every launch weapon has exactly one evolution and one pairing; pairings are
listed in the unlock panel once discovered.

Build variety comes from slot pressure and pairings, not from a synergy rule
system. Six weapons and six passives against eight and twelve options is
enough to make every run's build a decision.

### Health

Max health is a stat. Contact damage scales with the enemy's kind and the
timeline. Health regenerates slowly only through a passive. Healing pickups
drop rarely. A revive is a shop-bought permanent count.

---

## 7. Enemies

All enemies chase or pressure the player; none require pathfinding.

| Kind | Role | Behavior |
|---|---|---|
| Block | Crowd | Slow, tanky, walls of them. The baseline chaser. |
| Dart | Burst | Fast, fragile, straight rushes. Punishes standing still. |
| Spinner | Pressure | Tracks briefly, telegraphs, charges. Fair, readable. |
| Weaver | Area | Keeps distance, fires slow bullets. Prevents passive circling. |
| Elite | Beat | A larger, marked version of any kind with a chest. |
| Boss | Gate | Large, high health, unique telegraphed pattern, health bar. |

The four prototype silhouettes keep their looks and get the behaviors above;
the prototype's speed offsets are the seed of the roles.

Scaling is a function of the timeline minute, invisible to the player, with
no health bars except bosses. Spawn count is clamped to the entity budget;
when the budget is hit, spawns get tougher instead of more numerous.

---

## 8. Between Runs

### Gold

Gold drops from elites, bosses, and chests, and is awarded at the end of the
run from kills, minutes survived, and best combo. All of it is banked no
matter how the run ended. Gold is a plain integer with plain prices. No
second currency.

### Shop

Permanent power-ups bought with gold, each in ranks with escalating prices:
damage, fire rate, projectile count, area, speed, magnet, max health, armor,
regen, luck, gold gain, cooldown, revives, skips, rerolls. Ranks are small
percentages; the shop is a long, gentle curve, not a cliff.

One **refund** button returns every coin ever spent and clears all ranks.
Refund is free and unlimited. It lets players rebuild without regret and is
the reason there is no prestige system.

Prices follow one rule: the next affordable rank should cost about 1.3 runs
of typical gold income, so something is always almost affordable and never
affordable at the moment of death.

### Unlocks

A visible list. Every entry shows its condition, its progress, and what it
gives. Conditions are run facts: survive N minutes with a weapon, reach a
level, evolve a weapon, kill a boss, reach a combo. Entries unlock:

- weapons and passives beyond the launch roster
- ships: alternate player silhouettes with one starting weapon and one
  stat twist each
- stages: the arena with a modifier (denser, faster, darker), unlocked late

Unlocks are the collection loop. Unlocked items show in full; locked items
show as greyed silhouettes with their condition. The list is never complete
at launch.

### Results screen

Shown within half a second of the run's end. Always:

```text
RUN OVER                          (or CLEARED at the cap)

Survived 18:40   (best 19:12)
Level 31   Kills 2,317   Best combo x48
Build: Cannon IV · Orbit (evolved) · Seeker II · Nova I
       Magnet III · Damage II · Speed I

+412 gold   (banked: 1,988)
Next: Lance unlock — survive 15:00 with Cannon  (18:40 ✓)
      Armor rank 3 — 2,300 gold

[Retry]        [Shop]        [Unlocks]
```

Rules: retry is available immediately; the near-miss line reports real
proximity only; the next-unlock and next-purchase lines are always present;
a new best is starred.

---

## 9. Retention Design

The level-up bar, the combo, the gold total, the shop, the unlock list, and
the results screen are one system with one job: end every run with an open
loop the player wants to close. The levers come from the psychology under
monetized progression systems (Zachow, *Patterns and Psychology of Video
Game Monetization*, 2023) with the money removed and the author's ethical
line kept: low psychological complexity, transparent and predetermined
progression, no manufactured scarcity.

### Open loops

The engine is the Zeigarnik effect: an unfinished task pulls the player back.
Battle passes calibrate their reward spacing so that where playtesters stop,
they are most of the way to the next reward. WIPE calibrates the same way:

- The results screen always shows at least two open loops: the next unlock's
  progress and the next affordable shop rank. It also shows how far the
  level-up bar was at death.
- The next shop rank costs about 1.3 runs of gold.
- Unlock conditions are placed so that a typical run ends at 70–90% of the
  next one. Lower reads as impossible; higher closes the loop.
- The unlock panel shows greyed silhouettes for everything not yet seen. Set
  completion is its own pull.

### Predetermined, never random

Every unlock has a stated condition and a guaranteed result. The level-up
offer and chest contents are the only randomness, because there the roll is
the gameplay, not the reward for effort. No reward for effort is ever drawn
from a pool.

### Cadence

Front-load novelty, then stretch it. A new unlock lands in each of the first
three runs, then unlocks space out on a growing schedule, roughly runs 1, 2,
3, 5, 8, 12. Novelty carries the first session; open loops carry the rest.

### Every run pays

Gold banked regardless of outcome means a 4-minute death is still progress.
The results screen shows the banked total rising before anything else.

### Honest near-misses

"Survived 18:40 (best 19:12)" works because it is true. Thresholds are never
bent to manufacture proximity; that is the slot-machine mechanism and players
feel it. The unlock list reports real progress only.

### Not used

- Limited-time content, scarcity, or a streak that punishes a missed day.
- Any currency between gold and what it buys.
- Randomized delivery of unlocks or shop ranks.
- Prestige: the refundable shop plus escalating prices already solves the
  plateau, and a second progression axis splits attention. Revisit only if
  the shop curve is exhausted by playtesters.

### Measurement

Tuning cannot be done blind. The debug overlay logs five numbers per session
to the console, nothing persisted beyond the save file's own counters:

- runs per session
- retries within 3 seconds of a run's end
- median run length
- fraction of results screens with an unlock within 30% of its condition
- fraction of results screens with a shop rank within 30% of affordable

Tuning is a loop: playtest, read the five, move the timeline, prices, and
conditions.

---

## 10. UI

In-run HUD, top: level-up bar with level number; combo counter; timer;
gold this run. Bottom: weapon and passive icons with level pips. Health as a
bar under the ship. Boss health bar when a boss is alive. No score number:
the combo and the gold are the score.

Screens: level-up choice, results, shop, unlocks, ship select. Nothing
else. No settings screen at launch beyond volume and a deadzone slider on
the results screen.

Debug overlay (F1): FPS, frame time, enemy, bullet, particle, gem counts,
total entities, timeline minute, spawn rate, and the five session metrics.

---

## 11. Performance

The run length is the performance story. At 15 minutes the screen is full,
and that is the moment to say "this is built in With".

Targets on Steam Deck and the development desktop:

- stable 60 fps with 1,000 enemies, 500 bullets, 2,000 particles, 1,000 gems
- entity budget of 2,000 enemies, spawns clamped to it
- no per-frame allocation; pools sized at start
- restart under one second; the level-up pause and resume under one frame

The stress command (F3) fills the arena to the budget. Readability at that
density is a release requirement, measured on captured frames.

---

## 12. Persistence

A single save file: gold, shop ranks, unlock progress, bests, session
counters. Written on run end and on shop or refund changes. Corruption or
absence starts fresh with a notice. Nothing else persists.

---

## 13. Architecture

The simulation stays a pure, deterministic value with a tick; the platform
layers are facades around owned resources. See
[wipe-survival-implementation-notes.md](wipe-survival-implementation-notes.md)
for the shape of every system in current With. New systems follow the
prototype's pattern: state in the simulation, knobs in the rules value,
presentation reads and never writes.

The spawn timeline, weapon and passive tables, evolution pairings, shop
prices, and unlock conditions are data tables in the rules module so tuning
never touches system code.

---

## 14. Steam

Achievements mirror the unlock list one-to-one plus milestones: first clear,
first evolution, every boss, 10 and 50 and 100 runs. Achievements trigger on
the run fact, immediately, through the Steamworks flat C API modeled as a
facade. Steam Deck verified: controls, readability, and speaker mix checked
on the device. If Steam is not running the game runs without it and says so
once.

---

## 15. Milestones

Each milestone has a done condition. The next does not start before it.

### M1 — The run grows

XP gems with magnet and merge, level-ups with the choice screen, the Cannon
plus three other weapons, four passives, the 20-minute timeline with the
Reaper, elites with chests, one boss pattern at 5 and 10 minutes, health as
a stat, the results screen with gold and bests, a save file with gold and
bests.

Done when a 20-minute clear is possible for a good player and a first-run
death lands between 6 and 10 minutes.

### M2 — Between runs

The shop with all ranks, escalating prices, and refund. The unlock list with
the remaining launch weapons and passives as unlocks, two alternate ships.
Session metrics in the overlay.

Done when the five metrics read as designed across ten playtest sessions:
runs per session rising, most results screens showing an open loop within
30%.

### M3 — Variety and evolutions

All eight weapons, all passives, every evolution with its banner, the third
boss, the Spinner and Weaver behaviors, stages with modifiers.

Done when three distinct builds can clear and the unlock list is at least
half locked for a new player.

### M4 — Platform

Steamworks facade, achievements, Steam Deck acceptance on hardware,
listening review, store build.

Done when the acceptance record shows every hardware and listening check
green.

---

## 16. Out of Scope

Not in this spec, and not before every milestone is done:

- prestige (see §9)
- multiple arenas beyond stage modifiers
- story, characters with dialogue, tutorials beyond the first level-up hint
- dash, manual fire, weapon switching
- co-op or any multiplayer
- run modifiers chosen before a run, beyond stages
- a settings screen beyond volume and deadzone
- localization, controller rebinding, cloud saves
