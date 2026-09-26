# WIPE: SURVIVAL — Spec

One document. It replaces the recruiting prototype spec (complete, signed off
2026-09-25; this tree is its result) and the separate MVP and V1 specs. Scope
discipline lives in the milestones at the end, not in document boundaries.

---

## 1. Identity

WIPE is Geometry Wars' feel on Vampire Survivors' loop.

The frame is abstract space combat, never fantasy or horror. Every name in
this document follows that: enemies are geometry, the thing that ends a run
is the Null, drops are cores and credits, caches not chests, overclock not
curse, repair not healing, reboot not revive, and the enemy collection is a
registry. When a Vampire Survivors idea is borrowed, it is renamed into the
frame before it is written down.

Geometry Wars is a skill test with a wow factor, and a skill test with no
growth curve exhausts itself in an hour. Vampire Survivors is a growth curve:
the run itself grows, and every run feeds a permanent curve between runs. WIPE
keeps the first game's responsiveness, readability, and luminous chaos, and
builds the second game's loop under it.

The addiction is not one mechanic. It is three curves that overlap so that
one is always rising:

1. Power within the run: boosts, weapons, passives, merges.
2. Progress between runs: credits banked from every run, a shop of permanent
   power-ups, an unlock list.
3. A collection that is never complete: weapons, ships, merge recipes,
   the registry, stages.

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
- **Every run pays.** Credits are banked whatever happens. No run is wasted.

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
cap, the Null enters, unkillable to an ordinary build, and ends the run within seconds; surviving
to the cap counts as a clear.

**Endless.** Once a ship has cleared, endless is offered for that ship: the
timeline loops from minute 10 with every enemy stat and spawn count scaled
up per loop, no Null, and the run ends only in death. Endless is where
long-session players live once the roster is open, and it is where the
performance ceiling is actually reached. Bests and credits are tracked
separately for endless; unlock conditions count only capped runs.

### Timeline

Difficulty is a minute-by-minute spawn timeline, not a wave counter:

| Minutes | What happens |
|---|---|
| 0–2 | Chasers only, thin. First level-up within 30 seconds. |
| 2–5 | Density rises. Darts appear. First elite at 3:00. |
| 5–10 | Spinners and Weavers join. Elites every minute. Boss at 5:00 and 10:00. |
| 10–15 | Full roster, walls of enemies, second and third merges become reachable. |
| 15–20 | Screen-filling density. Boss at 15:00. the Null at 20:00. |

Every enemy kind, elite, boss, and event has a first-appearance minute in a
data table. The table is tuning, not architecture, and lives with the other
knobs.

### Pacing beats

- **Elites**: one larger, tougher enemy of an existing kind, marked
  visually, dropping a guaranteed supply cache.
- **Bosses**: at 5, 10, and 15 minutes. A boss is a screen-clear gate with a
  telegraphed pattern and a health bar, the one enemy health bar in the game.
- **Events**: scripted set pieces at fixed minutes, telegraphed two
  seconds ahead by a glow at the arena edge, lasting ten to twenty seconds
  over the normal spawns. They are the run's memorable beats and they are
  geometry: a diagonal sweep of Blocks across the arena, a ring of Darts
  converging on the ship, a spiral of Spinners unwinding from a corner, a
  lattice of Weavers holding formation. Twelve events at launch, each with
  its first minute in the table; enemies killed in an event drop cores as
  usual, so an event is also a core harvest for a strong build.
- **Caches**: dropped by elites and bosses. A cache is a ceremony: it opens
  with a spinning reveal of one item, or with luck three or five, each a
  boost choice in turn, a completed merge always first. Three- and five-item
  caches are where luck pays off, and the reveal is what makes a cache feel
  like a jackpot rather than a menu.
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
- **Level-up**: brief freeze, a pulse from the ship, a rising tone.
- **Merge**: the loudest non-death moment: freeze, screen flash, a named
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

### XP cores

Every kill drops a core. Cores are collected by proximity, with a magnet radius
that is a stat. Cores do double duty, which is where the two games meet:

- collecting fills the level-up bar
- collecting extends the combo; the combo decays after about two seconds
  without a core, resets on damage, and multiplies credits earned

Uncollected cores merge into larger cores after a few seconds so the floor
never fills with clutter.

### Pickups and fixtures

The arena has fixtures: a few glowing beacons at fixed points that any
bullet destroys, respawning elsewhere after a minute. A destroyed beacon
drops one pickup; elites and bosses drop them too. Pickups are why the
player crosses the arena instead of circling one spot:

| Pickup | Effect |
|---|---|
| Tractor | Pulls every core on screen to the ship |
| Clear | Kills every non-boss enemy on screen, dropping their cores |
| Freeze | Stops every enemy for five seconds |
| Repair | Restores 30% of max health |
| Credits | A chip, or rarely a bundle worth twenty |
| Cache | Rarely, from a beacon; always from an elite |

Pickups are collected on contact, are drawn brighter than cores, and never
expire. The bundle and the cache from a beacon are the reason a beacon at the
far wall is worth the trip.

### Level-ups

The level-up bar fills with XP; the XP needed per level grows so that early
levels come every 30 seconds and late levels every one to two minutes. A
level-up is a boost: the game pauses and offers a choice of three (four
with a luck passive):

- a merge, if a recipe is complete (always offered first; see Merges)
- a new weapon, if a weapon slot is free
- an upgrade to an owned weapon (up to level 8)
- a new passive, if a passive slot is free
- an upgrade to an owned passive (up to level 5)

A cache is also a boost, opened on the spot with the same choice.

Skip, reroll, and banish exist as shop-bought permanent counts, one per
run each at first. Skip declines the boost, reroll redraws it, and banish
removes an item from every later offer this run, which is what makes a
targeted build possible. Choosing resumes play immediately.

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
Plus cooldown, armor, luck, credit gain, and overclock as unlockables.

**Overclock** is the risk-reward lever: each level raises enemy speed, spawn
rate, and spawn count by a percentage, and raises XP and credits by the same
percentage. It is one number over the spawn table. An overclocked build reaches
merges sooner and dies faster, and it is the intended way to make a cleared
ship interesting again before endless.

### Merges

A merge is a recipe, and the rule is Vampire Survivors': the weapon
components at max level, the key passive merely held at any level. Once
the recipe is complete, the merged skill appears as a guaranteed option in
the next boost, taking one of the three choices. Picking it consumes the
weapon components into one merged weapon, named, visually distinct, and
much stronger. Not picking it keeps it in every following boost until it is
picked.

Two recipe shapes:

- **Evolution**: one weapon at max, keyed by a passive held at any level.
  The weapon evolves; the passive stays.
- **Union**: two weapons at max, keyed by a passive held at any level. The
  two become one, which frees a weapon slot, the strongest reward in a run.

Every launch weapon has exactly one evolution; four unions exist at launch.
Recipes are hidden until first discovered, then listed in the unlock panel
with their components. Merges are the late-run hook and the collection's
centerpiece: a player who knows a recipe plays the run to reach it.

Build variety comes from slot pressure and recipes, not from a synergy rule
system. Six weapons and six passives against eight and twelve options is
enough to make every run's build a decision.

### Health

Max health is a stat. Contact damage scales with the enemy's kind and the
timeline. Health regenerates slowly only through a passive. Repair pickups
drop rarely. A reboot is a shop-bought permanent count.

---

## 7. Enemies

All enemies chase or pressure the player; none require pathfinding.

| Kind | Role | Behavior |
|---|---|---|
| Block | Crowd | Slow, tanky, walls of them. The baseline chaser. |
| Dart | Burst | Fast, fragile, straight rushes. Punishes standing still. |
| Spinner | Pressure | Tracks briefly, telegraphs, charges. Fair, readable. |
| Weaver | Area | Keeps distance, fires slow bullets. Prevents passive circling. |
| Elite | Beat | A larger, marked version of any kind with a cache. |
| Boss | Gate | Large, high health, unique telegraphed pattern, health bar. |

The four prototype silhouettes keep their looks and get the behaviors above;
the prototype's speed offsets are the seed of the roles.

Scaling is a function of the timeline minute, invisible to the player, with
no health bars except bosses. Spawn count is clamped to the entity budget;
when the budget is hit, spawns get tougher instead of more numerous.

---

## 8. Between Runs

### Credits

Credits drop from elites, bosses, and caches, and is awarded at the end of the
run from kills, minutes survived, and best combo. All of it is banked no
matter how the run ended. Credits are a plain integer with plain prices. No
second currency.

### Shop

Permanent power-ups bought with credits, each in ranks with escalating prices:
damage, fire rate, projectile count, area, speed, magnet, max health, armor,
regen, luck, credit gain, cooldown, reboots, skips, rerolls. Ranks are small
percentages; the shop is a long, gentle curve, not a cliff.

One **refund** button returns every credit ever spent and clears all ranks.
Refund is free and unlimited. It lets players rebuild without regret and is
the reason there is no prestige system.

Prices follow one rule: the next affordable rank should cost about 1.3 runs
of typical credit income, so something is always almost affordable and never
affordable at the moment of death.

### Unlocks

A visible list. Every entry shows its condition, its progress, and what it
gives. Conditions are run facts: survive N minutes with a weapon, reach a
level, complete a merge, kill a boss, reach a combo. Entries unlock:

- weapons and passives beyond the launch roster
- ships: see §9; each has its own condition, from trivial to very specific
- stages: the arena with a modifier (denser, faster, darker), unlocked late

Unlocks are the collection loop. Unlocked items show in full; locked items
show as greyed silhouettes with their condition. The list is never complete
at launch.

### Registry

A third collection grid beside weapons and ships: every enemy kind, elite,
boss, and event, with lifetime kills, first seen, and the minute it first
appears once discovered. Entries are silhouettes until first killed. The
results screen feeds it with kills per kind for the run. The registry costs
nothing, the simulation already counts, and it is one more grid that is
never full.

### Results screen

Shown within half a second of the run's end. Always:

```text
RUN OVER                          (or CLEARED at the cap)

Survived 18:40   (best 19:12)
Level 31   Kills 2,317 (Block 1,402 · Dart 611 · Spinner 231 · Weaver 73)
Best combo x48
Build: Cannon IV · Orbit (merged) · Seeker II · Nova I
       Magnet III · Damage II · Speed I

+412 credits   (banked: 1,988)
Next: Lance unlock — survive 15:00 with Cannon  (18:40 ✓)
      Armor rank 3 — 2,300 credits

[Retry]        [Shop]        [Unlocks]
```

Rules: retry is available immediately; the near-miss line reports real
proximity only; the next-unlock and next-purchase lines are always present;
a new best is starred.

---

## 9. Ships

Ships are the roster. Each is a different opening and a different build
pressure, and each unlock condition is a goal in its own right. Like
Vampire Survivors' characters, they are the most visible half-empty grid in
the game, and the reason a player who has cleared a run starts another.

### Rules

- **One silhouette.** Readable at any density and distinct from every enemy
  and every other ship. The prototype's open claw is the language; every ship
  is an open, asymmetric shape.
- **One base weapon**, fixed in the first slot, never removable. It is the
  ship's identity and it shapes the build from the first level-up.
- **One strength and one weakness**, both stated on the ship's card in plain
  numbers. A weakness is a real cost, not flavor: a ship that cannot aim, a
  ship with one hit point, a ship that cannot take the Cannon.
- **One unlock condition**, a run fact, shown with live progress in the
  unlock panel. Conditions are graded: three are met by playing normally in
  the first hour; three take a deliberate run; two take a specific,
  demanding achievement. One is secret, shown as a hint rather than hidden.
- **Ships do not stack with the shop.** Shop ranks apply to every ship
  equally; a ship's strength is a multiplier on top, never a substitute.
- **Every ship can clear.** A weakness makes a ship harder or stranger, never
  impossible. Tuning target: a good player clears with any unlocked ship.

### Launch roster

| Ship | Base weapon | Strength | Growth | Weakness | Unlock |
|---|---|---|---|---|---|
| Claw | Cannon | Balanced; +1 reroll per run | +1% damage per level | None | Start |
| Dart | Seeker | +25% move speed, +20% projectile speed | +1% move speed per level | Max health 2 | Survive 5:00 |
| Hull | Nova | +50% max health, +1 armor | +1 max health every 5 levels | −20% move speed | Take 20 hits in one run and survive |
| Prism | Shard | Shards bounce twice more; +20% area | +1% area per level | −15% damage | Kill 200 enemies with bounced shards |
| Halo | Orbit | +60% magnet, cores worth +25% XP | +2% magnet per level | Cannot take the Cannon | Collect 5,000 cores, lifetime |
| Needle | Lance | +35% damage, lance pierces everything | +1% damage per level, +5% every 10 | Cannot aim: no Cannon, and the right stick does nothing | Reach combo x60 |
| Sapper | Mines | +40% area, mines chain-detonate | +1% cooldown per level | Only 4 weapon slots | Complete two merges in one run |
| Phase | Arc | Invulnerable for 2 seconds on every level-up | +0.1 s invulnerability every 5 levels | Max health 1; reboots do not work | Clear a 20-minute run with no reboot |
| Null | Shear (unique) | Starts at level 5 with 3 weapons; +30% credits | +1% credits per level | −40% XP gain; cannot merge | Secret: "Face what ends the run, and end it first" |

Growth is a ship's stat gain per level within the run, so a ship's identity
sharpens across twenty minutes instead of being fixed at the start. It is a
column in the same data table as the rest of the ship.

The Null is the mirror of Vampire Survivors' Red Death: the Null that
arrives at the 20-minute cap is unkillable to an ordinary build, and a build
that kills it unlocks the ship. Its condition is the one hint on the panel;
its progress shows only after the first attempt.

### Ship select

Ship select is a screen only after the first ship is unlocked. Before that,
launching starts a run as the Claw with no screen at all. The screen shows
every ship, locked ones greyed with their condition and progress, and
remembers the last choice.

### Ships in the loop

- The results screen's next-unlock line prefers a ship when one is within
  30% of its condition, because a ship is the largest single reward the
  game gives.
- A newly unlocked ship is offered on the results screen with one button:
  retry as it. Novelty should be one press away.
- Achievements mirror ship unlocks one-to-one (§15).

---

## 10. Retention Design

The level-up bar, the combo, the credit total, the shop, the unlock list, and
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
- The next shop rank costs about 1.3 runs of credits.
- Unlock conditions are placed so that a typical run ends at 70–90% of the
  next one. Lower reads as impossible; higher closes the loop.
- The unlock panel shows greyed silhouettes for everything not yet seen. Set
  completion is its own pull.

### Predetermined, never random

Every unlock has a stated condition and a guaranteed result. The level-up
offer and cache contents are the only randomness, because there the roll is
the gameplay, not the reward for effort. No reward for effort is ever drawn
from a pool.

### Cadence

Front-load novelty, then stretch it. A new unlock lands in each of the first
three runs, then unlocks space out on a growing schedule, roughly runs 1, 2,
3, 5, 8, 12. Novelty carries the first session; open loops carry the rest.

### Every run pays

Credits banked regardless of outcome means a 4-minute death is still progress.
The results screen shows the banked total rising before anything else.

### Honest near-misses

"Survived 18:40 (best 19:12)" works because it is true. Thresholds are never
bent to manufacture proximity; that is the slot-machine mechanism and players
feel it. The unlock list reports real progress only.

### Not used

- Limited-time content, scarcity, or a streak that punishes a missed day.
- Any currency between credits and what it buys.
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

## 11. UI

In-run HUD, top: level-up bar with level number; combo counter; timer;
credits this run. Bottom: weapon and passive icons with level pips. Health as a
bar under the ship. Boss health bar when a boss is alive. No score number:
the combo and the credits are the score.

Screens: level-up choice, results, shop, unlocks, ship select. Nothing
else. No settings screen at launch beyond volume and a deadzone slider on
the results screen.

Debug overlay (F1): FPS, frame time, enemy, bullet, particle, core counts,
total entities, timeline minute, spawn rate, and the five session metrics.

---

## 12. Performance

The run length is the performance story. At 15 minutes the screen is full,
and that is the moment to say "this is built in With".

Targets on Steam Deck and the development desktop:

- stable 60 fps with 1,000 enemies, 500 bullets, 2,000 particles, 1,000 cores
- entity budget of 2,000 enemies, spawns clamped to it
- no per-frame allocation; pools sized at start
- restart under one second; the level-up pause and resume under one frame

The stress command (F3) fills the arena to the budget. Readability at that
density is a release requirement, measured on captured frames.

---

## 13. Persistence

The player never loses a save. That is the whole requirement; the rules
below are how it is met.

### What persists

One save: credits, shop ranks, unlock progress, bests, lifetime counters
(runs, kills, minutes, clears), and the session metrics of §10. Nothing else.
A run in progress is never saved; a crash mid-run loses the run and never
the account.

### Load at launch

The save is read before the first frame of gameplay. Launching is loading:
there is no continue button, and the first run already reflects every shop
rank and unlock. Loading a missing file is the new-player path, silently.

### Save on every change

The save is written at every point state changes, not only at run end:

- run end, the moment the results screen appears, with the run's credits
  already banked
- every shop purchase and every refund
- every unlock and every new best

So the most a crash or a power loss can cost is the run on screen.

### Atomic writes with a backup

A write goes to a temporary file in the save directory, is flushed, and is
renamed over the current save. The current save is renamed to `.bak` first.
A crash during a write leaves the previous save intact; there is never a
half-written save on disk.

On load, if the primary fails to parse, the backup is loaded and the player
is told once. Only if both fail does the game start fresh, and then it sets
the two files aside under a dated name rather than deleting them, and says
so.

### Versioned format

The file carries a schema version. A newer game reads every older version
and rewrites the file in the current one. An older game reading a newer
file refuses and says which version it needs; it never starts fresh over a
save it cannot read.

### Location

The platform's per-user application data directory, never beside the
executable, so moving or reinstalling the game never touches the save.
The exact path is shown in the debug overlay.

### Later

The format above is what makes Steam Cloud possible without a migration.
Cloud sync stays out of scope (§17) until the platform milestone.

---

## 14. Architecture

The simulation stays a pure, deterministic value with a tick; the platform
layers are facades around owned resources. See
[wipe-survival-implementation-notes.md](wipe-survival-implementation-notes.md)
for the shape of every system in current With. New systems follow the
prototype's pattern: state in the simulation, knobs in the rules value,
presentation reads and never writes.

The spawn timeline, weapon and passive tables, merge recipes, shop
prices, and unlock conditions are data tables in the rules module so tuning
never touches system code.

---

## 15. Steam

Achievements mirror the unlock list one-to-one plus milestones: first clear,
first merge, every boss, 10 and 50 and 100 runs. Achievements trigger on
the run fact, immediately, through the Steamworks flat C API modeled as a
facade. Steam Deck verified: controls, readability, and speaker mix checked
on the device. If Steam is not running the game runs without it and says so
once.

---

## 16. Milestones

Each milestone has a done condition. The next does not start before it.

### M1 — The run grows

XP cores with magnet and merge, level-ups with the choice screen, the Cannon
plus three other weapons, four passives including overclock, the 20-minute
timeline with the Null, four events, beacons and the pickup set, elites
with caches, one boss pattern at 5 and 10 minutes, health as a stat, the
results screen with credits and bests, and the save as §13 states
it: loaded before the first frame, written on every change, atomic with a
backup, versioned, in the per-user data directory.

Done when a 20-minute clear is possible for a good player, a first-run
death lands between 6 and 10 minutes, and killing the process at any moment
of a run, a purchase, or a save write leaves the account intact on the next
launch.

### M2 — Between runs

The shop with all ranks, escalating prices, and refund, including skip,
reroll, and banish counts. The unlock list with the remaining launch weapons
and passives as unlocks, and the registry. The Dart and the Hull, and the
ship select screen. Session metrics in the overlay.

Done when the five metrics read as designed across ten playtest sessions:
runs per session rising, most results screens showing an open loop within
30%.

### M3 — Variety and merges

All eight weapons, all passives, every evolution and union with its banner,
the third boss, the Spinner and Weaver behaviors, all twelve events, the
cache ceremony with three- and five-item caches, stages with modifiers, the
full ship roster including the killable Null and its ship, and endless
mode.

Done when three distinct builds can clear, every ship can clear in a good
player's hands, endless holds 60 fps through its third loop, and the unlock
list is at least half locked for a new player.

### M4 — Platform

Steamworks facade, achievements, Steam Deck acceptance on hardware,
listening review, store build.

Done when the acceptance record shows every hardware and listening check
green.

---

## 17. Out of Scope

Not in this spec, and not before every milestone is done:

- prestige (see §10)
- multiple arenas beyond stage modifiers
- story, characters with dialogue, tutorials beyond the first level-up hint
- dash, manual fire, weapon switching
- co-op or any multiplayer
- run modifiers chosen before a run, beyond stages
- a settings screen beyond volume and deadzone
- localization, controller rebinding, cloud saves
