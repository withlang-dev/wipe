# WIPE: SURVIVAL — Progression Matrix

The item-by-item schedule for [progression-plan.md](progression-plan.md):
when each weapon, passive, ship and stage enters the pool, what keys its
evolution, which ship teaches it, when a player should first meet it, and
which gameplay axis it exercises. The point is to see collisions and dead
zones before writing twelve weapons. Hours are the median fresh account's
and are acceptance metrics, never unlock conditions (plan §4).

Tiers: **1** starter pool; **2** first boss, 5:00 and 8:00 survived; **3**
first merge, first stage, 12:00; **4** first clear, Hurry, challenges.

## 1. Weapons

Review columns: **Input** (aim stick, move stick, turning), **Movement**
(rewards or punishes a way of moving), **Geometry** (walls, arena shape,
position). Blank in all three means the weapon is questioned (plan §2).

| # | Weapon | Family | Tier | Hour | Evolution | Key | Union | Specialist ship | Damage role | Input | Movement | Geometry |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Cannon | Aimed | 1 | 0 | Railgun | FireRate | Tracer (+Seeker) | Claw | single-target DPS | aim | — | — |
| 2 | Orbit | Orbiting | 1 | 0 | Corona | Area | Pulsar (+Nova) | — | close defense | — | hugging crowds | — |
| 3 | Nova | Ring | 1 | 0 | Supernova | Health | Pulsar, Well Burst | — | periodic clear | — | standing in the thick | — |
| 4 | Seeker | Homing | 1 | 0 | Swarm | ProjSpeed | Tracer | — | spread DPS | — | — | — |
| 5 | Lance | Beam | 1 | 0.3 | Pike | Damage | Refractor (+Shard) | Needle | line pierce | move stick | strafing lines | — |
| 6 | Arc | Chain | 1 | 0 | Storm | Count | Grid (+Mines) | — | crowd chain | — | — | — |
| 7 | Proximity Mine | Dropped | 1 | 0.3 | Minefield | Cooldown | Grid | Sapper | area denial | — | keep moving to lay | chokepoints |
| 8 | Shard | Bouncing | 2 | 0.8 | Shatter | Speed | Refractor | Prism | wall-fed spread | aim | — | walls, corners |
| 9 | Tether | Orbiting | 2 | 0.5 | Long Tether | Duration | — (waits) | Lasher | sweep | turning | committed turns | — |
| 10 | Gravity Well | Field | 2 | 0.7 | Singularity | Magnet | Well Burst (+Nova) | Anchor | pull + crush | — | positioning the well | arena center |
| 11 | Drone | Homing | 2 | 1.0 | Twin Drones | Count | Net (+Turret) | Carrier | flank DPS | aim cone defines flank | — | — |
| 12 | Lob | Aimed | 2 | 1.2 | Barrage | Area | — | Mortar ship | far burst | aim past near | min range forces spacing | — |
| 13 | Flak | Aimed | 3 | 1.5 | Shrapnel | Pierce | — | — | short cone | aim | closing in | — |
| 14 | Turret | Dropped | 3 | 1.8 | Battery | Duration | Net (key Salvage) | — | placed DPS | — | choosing a spot | corners, lanes |
| 15 | Sweep | Beam | 3 | 2.0 | Lighthouse | Rebound | — | — | rotating DoT | — | — | — |
| 16 | Tesla Field | Chain | 3 | 2.2 | Storm Cage | Cooldown | — | — | radius DoT | — | hugging crowds | — |
| 17 | Boomerang | Bouncing | 3 | 2.5 | Twin Return | ProjSpeed | — (waits) | — | out-and-back | aim | — | — |
| 18 | Shockwave | Ring | 4 | 3.0 | Tremor | Armor | — | — | push + mark | — | standing ground | — |
| 19 | Satellite | Field | 4 | 3.5 | Constellation | Luck | — | — | intercept | — | — | orbit geometry |
| 20 | Repulsor | Field | 4 | 4.0 | Bastion | Health | — | — | safe zone | — | retreating | — |

Shelf: Decoy (attacks the AI, not HP; experimental).

Unions (6, room for 8): Tracer, Pulsar, Grid, Refractor, **Well Burst**
(Gravity Well + Nova, key Area), **Net** (Drone + Turret, key Salvage).
Waiting for a concept neither part has alone: Tether + Boomerang, Lob +
Shockwave.

**Implemented 2026-10-14:** all twenty base weapons, their twenty
evolutions and the six unions above, with Duration, Pierce and Failsafe.
Weapon indices are base 0-19, evolutions 20-39, unions 40-45; save files
are version 3 and older files' indices are remapped on load.

Tier-1 pool is weapons 1–7 (seven; Lance and the Mine arrive within the
first runs by survival). Tier 2 adds 8–12, tier 3 adds 13–17, tier 4 the
rest.

Aim-identity check: weapons with a non-blank Input, Movement or Geometry
column: 1, 5, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 19, 20 = 14 of 20. The
never-aim builds (2, 3, 4, 6, 15, 17) exist on purpose.

## 2. Evolution keys

| Passive | Tier | Keys |
|---|---|---|
| Damage | 1 | Lance → Pike |
| FireRate | 1 | Cannon → Railgun |
| Count | 1 | Arc → Storm; Drone → Twin Drones |
| Area | 1 | Orbit → Corona; Lob → Barrage |
| ProjSpeed | 1 | Seeker → Swarm; Boomerang → Twin Return |
| Magnet | 1 | Gravity Well → Singularity |
| Speed | 1 | Shard → Shatter |
| Health | 1 | Nova → Supernova; Repulsor → Bastion |
| Cooldown | 2 | Proximity Mine → Minefield; Tesla Field → Storm Cage |
| Armor | 2 | Shockwave → Tremor |
| Luck | 2 | Satellite → Constellation |
| Credit | 2 | Drone + Turret → Net |
| Rebound | 3 | Sweep → Lighthouse |
| Overclock | 3 | — |
| Duration | 2 | Tether → Long Tether; Turret → Battery |
| Pierce | 3 | Flak → Shrapnel |
| Failsafe | 3 | — |

Distribution (as implemented 2026-10-14): no passive keys more than two;
Cooldown and Damage, the premium stats, key one and two mid-tier weapons,
not the top ones; Failsafe keys nothing and is pure survival. Sweep's key
moved to Rebound so Duration keys two.

## 3. Passives

| # | Passive | Tier | Condition | Role |
|---|---|---|---|---|
| 1 | Damage | 1 | start | offense |
| 2 | Fire rate | 1 | start | offense |
| 3 | Projectiles | 1 | start | offense |
| 4 | Area | 1 | start | offense |
| 5 | Velocity | 1 | start | offense |
| 6 | Magnet | 1 | start | economy |
| 7 | Thrusters | 1 | start | mobility |
| 8 | Hull | 1 | start | survival |
| 9 | Cooldown | 2 | 3 bosses (was 5) | offense, premium |
| 10 | Armor | 2 | 40 hits taken (was 100) | survival |
| 11 | Luck | 2 | 5 caches (was 10) | economy |
| 12 | Salvage | 2 | 2,000 credits banked (was 5,000) | economy |
| 13 | Rebound | 3 | 50 bounced kills | geometry |
| 14 | Overclock | 3 | 6 bosses (was 8) | danger for reward |
| 15 | Duration | 2 | survive 8:00 | offense |
| 16 | Pierce | 3 | first merge | offense |
| 17 | Failsafe | 3 | die 10 times | survival, one revival |
| 18 | (reserved) | 4 | — | a displacement passive if §5.4 wants one |

Conditions in parentheses are today's; the lowered numbers are the plan's
first guesses, to be set by `runs`.

## 4. Ships

| # | Ship | Tier | Start weapon | Condition | Identity | Hour |
|---|---|---|---|---|---|---|
| **Authored** | | | | | | |
| 1 | Claw | 1 | Cannon | start | the baseline | 0 |
| 2 | Dart | 1 | Cannon | survive 5:00 | fast, fragile, +1 projectile | 0.2 |
| 3 | Hull | 2 | Nova | 20 hits survived | the wall: health doubles, armor | 0.7 |
| 4 | Prism | 2 | Shard | 100 bounced kills (was 200) | the wall-player | 1.5 |
| 5 | Halo | 3 | Orbit | 2,000 lifetime cores (was 5,000) | no Cannon, ring master | 2 |
| 6 | Needle | 3 | Lance | combo ×1,500 (was 3,000) | no aim at all | 2.5 |
| 7 | Sapper | 3 | Proximity Mine | 2 merges in a run | 3 weapon slots | 2.5 |
| 8 | Phase | 4 | Cannon | clear without a reboot | 1 hull, long invulnerability | 3 |
| 9 | Lasher | 2 | Tether | the Corridor's black box | turning is the weapon; slow strafe | 1.2 |
| 10 | Anchor | 3 | Gravity Well | hold the Shaft's derelict a minute | cannot move while a well is live | 2 |
| 11 | Carrier | 3 | Drone | kill the Ring's carrier | no Cannon; two drones from the start | 2.5 |
| 12 | Warden | 4 | Repulsor | clear in Hurry | regenerates in the zone, nothing else | 5 |
| **Specialists** | | | | | | |
| 13 | Hawk | 2 | Seeker | survive 8:00 | +projectile speed, +1 seeker | 0.5 |
| 14 | Volt | 2 | Arc | kill 5 elites | +damage, faster lightning | 0.6 |
| 15 | Mortar | 2 | Lob | survive 12:00 | shells fly farther | 1.2 |
| 16 | Brace | 3 | Flak | survive 5:00 holding the Flak | +1 fragment a fan | 1.8 |
| 17 | Sentry | 3 | Turret | the Cross's relays | emplacements stand longer | 2 |
| 18 | Lantern | 3 | Sweep | survive 15:00 | faster cooldowns, quicker beam | 2.2 |
| 19 | Coil | 3 | Tesla Field | kill 6 bosses | +area, wider field | 2.5 |
| 20 | Kestrel | 3 | Boomerang | survive 5:00 holding the Boomerang | +projectile speed, +1 boomerang | 3 |
| 21 | Rampart | 4 | Shockwave | clear a run | +1 armor, harder shove | 3.5 |
| 22 | Orbital | 4 | Satellite | survive 30 hits in a run | +2 hull, wider orbit | 4 |
| **Secrets** | | | | | | |
| 23 | Null | 4 | Cannon | kill the Null | -25% XP, cannot merge | 6+ |
| 24 | Ghost | 4 | Satellite | lose 25 runs | passives only until level 8, then double damage | 4 |
| 25 | Mirror | 4 | Shard | clear the mirrored stage (phase 8) | every projectile is reflected once | 5 |
| 26 | Glass | 4 | Lob | catch the Expanse's drifting wreck | 1 hull, triple damage | 6+ |

Twelve authored, ten specialists, four secrets: 26. The specialists are
thin by design (one weapon, one stat lean) and exist to put each family in
the player's hands within a run of unlocking it; the authored ships carry
the roster. Lowered conditions in parentheses are first guesses.

Derelict verbs (implemented 2026-10-14): the Corridor's black box
(Lasher), the Shaft's minute held (Anchor), the Cross's three relays
(Sentry), the Expanse's drifting wreck (Glass), the Ring's carrier
(Carrier). Survive-the-zone waits for Rotor. Twenty-five ships ship;
Mirror comes with its stage.

## 5. Stages

| # | Stage | Kind | Opens | Variable changed | Hour |
|---|---|---|---|---|---|
| 1 | Field | normal | start | the baseline | 0 |
| 2 | Corridor | normal | level ~12 in a run | geometry: a lane; derelict (black box) | 0.3 |
| 3 | Shaft | normal | level ~20 | geometry: vertical, wells; derelict (defend) | 1 |
| 4 | Ring | normal | level ~28 | geometry: a dead center; spawn topology | 1.5 |
| 5 | Cross | normal | level ~35 | geometry: four arms meeting; derelict (relays) | 2 |
| 6 | Pillars | bonus, 10 min | survive 10:00 | geometry: cover | 0.8 |
| 7 | Maze | bonus, 10 min | Corridor opened | geometry: walls everywhere; Shard and Mines shine | 1 |
| 8 | Gridlock | bonus, 10 min | 3 merges lifetime | spawn topology: fixed gates | 1.8 |
| 9 | Expanse | bonus, 10 min | Ring opened | geometry: huge, no walls; derelict (chase) | 2 |
| 10 | Blackout | bonus, 10 min | 50 elites | visibility: a cone of light | 2.5 |
| 11 | Boss Rush | challenge, 15 min | first Hurry clear | composition: bosses only; derelict (carrier) | 4 |
| 12 | Bone Field | challenge | Hurry clear | HP ×(1 + 0.3 × minute); density flat | 4.5 |
| 13 | Collapse | challenge | 2 challenge clears | geometry over time: the arena shrinks | 5 |
| 14 | Rotor | challenge | 2 challenge clears | mobility: rotating safe sectors; derelict (survive the zone) | 5.5 |
| 15 | Mirror | hidden | found through Cross's black box | geometry: mirrored arena; Mirror ship | 6+ |

Modes: Hurry (first clear), Endless (kill the Null), with `timeline_rate`
the one knob (plan §8).

**Implemented 2026-10-14:** all fifteen stages. Blackout (a cone of light,
drawing only, ten minutes), Boss Rush (a boss every three minutes and
nothing else, fifteen minutes), Bone Field (hull grows 30% a minute, the
spawn tables held at minute six), Collapse (55 px a minute off every
side, never past a small room), Rotor (a sixth of the circle safe,
turning once a minute, two hull a second outside; the survive-the-zone
derelict), Mirror (every spawn's twin across the middle; the Mirror ship
on clearing it). Rotor and Collapse open on two challenge clears, Boss
Rush on a Hurry clear, Bone Field on fifteen bosses, Blackout on fifty
elites, Mirror through the Cross's relays. Endless opens with the Null.

## 6. Dead zones and collisions found

- **Hour 0–0.5 has one new ship (Dart) and no new weapon**: Lance's
  condition moves from "survive 15:00 with Cannon" to "survive 3:00", so a
  weapon arrives in run one.
- **Shard at 30,000 lifetime kills** is hours away; it becomes tier 2 at
  "100 wall kills", so Prism's path opens in hour one.
- **Five derelicts use five different verbs**; the remaining ten stages
  reuse them, no verb more than three times.
- **Duration keys three evolutions**; flagged above.
- **Tier 4 holds five weapons and six ships**: that is the 3–6 hour band,
  which VS fills with secrets, and is the right place for them.
