# Progression control group (2026-10-13)

The cadence of the game as it was before any gate moved, from
`runs account` (every recorded run scored from the save in its own header)
and `runs account-sim` (a fresh account played by the careful bot on the
Claw in the Field, buying the cheapest affordable rank after each run).
The score and the events are progression-plan §3.

## Eric's account, 62 recordings

Mostly short test sessions (fifty runs under thirty seconds), with the save
edited once between runs 20 and 21, so this is a smoke test of the tool
more than a measure of play. The numbers that matter will come from play
sessions after this date.

```text
runs 62, account hours 0.9
zero-progress runs 50, longest zero-progress streak 19
progression events 33, per hour 36
first weapon unlock   run 21, minute 8
first ship unlock     run 21, minute 8
first merge           run 21, minute 8
first new stage       run 21, minute 8
first clear           never
first Hurry clear     never
```

Replaying and scoring all 62 took 2.4 s.

## The bot account, 20 runs

The bot clears the Field on run 5, at account minute 66, and from then on
every run clears; its only progression after run 5 is ranks (it never
changes ship or stage, and its unlocks come from lifetime counters). The
first weapon arrives on run 3, the first ship on run 1, the first merge on
run 2, the first new stage with the first clear. Twenty full runs took
about four minutes of wall time.

```text
run 1  8:55  score 13  ship:Dart afford:Magnet 1 goal:Halo ship goal:Needle ship goal:Lance goal:Shard goal:Cooldown goal:Luck goal:Salvage goal:Cross stage
run 2  9:39  score 20  ship:Halo merge:Supernova rank:Damage 1 rank:Area 1 rank:Thrusters 1 rank:Magnet 2 rank:Hull 1 goal:Sapper ship goal:Shard goal:Cooldown goal:Salvage
run 3  17:43  score 34  ship:Needle weapon:Lance weapon:Shard passive:Cooldown passive:Luck passive:Salvage merge:Tracer rank:Fire rate 1 rank:Area 2 rank:Thrusters 2 rank:Luck 1 rank:Salvage 1 goal:Overclock goal:Shaft stage goal:Cross stage
run 4  9:55  score 24  rank:Damage 2 rank:Fire rate 2 rank:Area 3 rank:Thrusters 3 rank:Magnet 3 rank:Hull 2 rank:Repair 1 rank:Luck 2 rank:Cooldown 1 rank:Skips 1 rank:Rerolls 1 rank:Banish 1
run 5  20:00  score 25  ship:Prism ship:Phase passive:Rebound passive:Overclock stage:Corridor stage:Cross rank:Magnet 4 rank:Salvage 2 rank:Skips 2 goal:Shaft stage
run 6  12:21  score 11  stage:Shaft rank:Damage 3 rank:Hull 3 rank:Armor 1 rank:Cooldown 2
run 7  20:00  score 9  merge:Shatter rank:Fire rate 3 rank:Thrusters 4 rank:Rerolls 2
run 8  20:00  score 9  weapon:Mines rank:Repair 2 rank:Luck 3 rank:Banish 2
run 9  20:00  score 10  stage:Ring merge:Railgun rank:Area 4 rank:Salvage 3
run 10  20:00  score 7  ship:Sapper rank:Magnet 5 rank:Skips 3
run 11  20:00  score 9  merge:Corona rank:Hull 4 rank:Armor 2 rank:Cooldown 3
run 12  20:00  score 7  merge:Pike rank:Damage 4 rank:Fire rate 4
run 13  16:53  score 6  rank:Projectiles 1 rank:Thrusters 5 rank:Rerolls 3
run 14  20:00  score 8  rank:Area 5 rank:Repair 3 rank:Luck 4 rank:Banish 3
run 15  20:00  score 2  rank:Salvage 4
run 16  20:00  score 5  rank:Hull 5 rank:Armor 3 goal:Hull ship
run 17  20:00  score 2  rank:Reboots 1
run 18  20:00  score 4  rank:Damage 5 rank:Cooldown 4
run 19  20:00  score 2  rank:Fire rate 5
run 20  20:00  score 2  rank:Projectiles 2
runs 20, account hours 5.9
zero-progress runs 0, longest zero-progress streak 0
progression events 101, per hour 17
first weapon unlock   run 3, minute 36
first ship unlock     run 1, minute 8
first merge           run 2, minute 18
first new stage       run 5, minute 66
first clear           run 5, minute 66
first Hurry clear     never
```

## What the control says

- The bot's hour one already meets the plan's first-ship and first-merge
  targets and misses first-weapon (run 3) and first-stage (run 5, tied to
  the clear): the two things phase 2 and the matrix's lowered conditions
  change.
- `zero_progress_streak` is 0 for the bot because the shop keeps paying;
  Eric's test log shows what a human's looks like when it isn't (19).
- Scoring is cheap enough to run on every account: 62 recordings in 2.4 s.


## After phases 2 and 3 (level gates, Hurry, staged content), the bot, 6 runs

The first new stage moves from run 5 to run 1 (Corridor at level 12), the
first weapon from run 3 to run 1 (the Lance at 3:00 survived, the Mines at
5:00), and every weapon is picked within two runs of its unlock: the
exposure the fresh-card weight is for. The Cannon never shows as picked
because the starting weapon is never a card. The bot's own runs are
shorter under the new pool (Shard now waits for 100 wall kills, and the
Lance comes early), which phase 4 tunes.

```text
run 1  8:14   score 18  ship:Dart, weapon:Lance, weapon:Mines, stage:Corridor, ...
...
runs 6, account hours 1
zero-progress runs 0, longest zero-progress streak 0
progression events 61, per hour 56
first weapon unlock   run 1, minute 8
first ship unlock     run 1, minute 8
first merge           run 4, minute 42
first new stage       run 1, minute 8
first clear           never
first Hurry clear     never
weapon     unlocked  first pick  gap
Cannon    start    never    never
Orbit    start    run 1    1
Nova    start    run 1    1
Seeker    start    run 1    1
Lance    run 1    run 2    1
Mines    run 1    run 2    1
Arc    start    run 2    2
Shard    never    never    -
```

## After phase 4 (fewer, tougher; XP per hull; ranks a run apart), the bot, 8 runs

Enemy hull: a Block has 2 by 1:30, 4 by 3:00, 8 by 5:00, 28 by 10:00
(was 1 until about 1:40, 9 at 5:00, 19 at 10:00); the alive floor and the
trickle at twenty minutes are a little over half what they were. XP per
kill follows hull (`xp_per_hp 0.05`, capped at 2.5x), so the careful
Claw's level is 11-13 at 5:00 and 17-22 at 10:00 against 13 and 19
before. Aimed and beam damage rose a third so single-target weapons keep
their bands. Ranks: +35% for the first five of an item, +60% after; the
shop leads with hull, armor and a reboot.

`runs profile 6 RANKS Claw`: ranks 0 reach 10:00 on 2 of 6 seeds, ranks 3
on 4 of 6, ranks 6 reach 15:00 and 20:00 on 2 of 6.

```text
run 7  17:07  score 10  merge:Pike, rank:Magnet 5, rank:Salvage 3, rank:Skips 3, goal:Armor,
run 8  19:10  score 13  passive:Armor, rank:Damage 4, rank:Fire rate 4, rank:Hull 4, rank:Armor 2, rank:Cooldown 3,
runs 8, account hours 1.9
zero-progress runs 0, longest zero-progress streak 0
progression events 82, per hour 42
first weapon unlock   run 1, minute 11
first ship unlock     run 1, minute 11
first merge           run 1, minute 11
first new stage       run 1, minute 11
first clear           run 4, minute 59
first Hurry clear     never
weapon     unlocked  first pick  gap
```

## After phases 5-8 (the arsenal, the roster, the stages), the bot, 8 runs

The bot plays the Claw in the Field, so the new stages and ships do not
show here, but the pool does: twenty weapons enter by accomplishment and
the bot meets most within two runs of their unlock. The gaps it leaves
(the Tether at five runs, the Flak at seven, the Turret never) are the
careful bot's card policy, which takes upgrades over new weapons once its
slots fill; the fresh-card weight raises the offer, not the pick. A
human's exposure is the number to watch, from `runs exposure` on a real
account.

```text
first Hurry clear     never
weapon     unlocked  first pick  gap
Cannon    start    never    never
Orbit    start    run 1    1
Nova    start    run 5    5
Seeker    start    run 1    1
Lance    run 1    run 2    1
Mines    run 1    run 2    1
Arc    start    run 1    1
Shard    never    never    -
Tether    run 1    run 6    5
Gravity Well    run 1    run 3    2
Drone    run 1    run 2    1
Lob    run 1    run 3    2
Flak    run 1    run 8    7
Turret    run 1    never    never
Sweep    run 1    run 5    4
Tesla Field    run 3    run 4    1
Boomerang    never    never    -
Shockwave    run 4    run 6    2
Satellite    run 8    never    never
Repulsor    run 4    run 5    1
```

## After the balancing campaign (Tanks, the hooks, the number pass), the bot, 4 seeds a ship

The first per-ship cadence. The careful bot flies every ship in the Field
at rank zero; the columns are seeds surviving past each minute. The Claw
is the yardstick and the runaway guard in `targets.w` holds it at six of
eight past fifteen. The Mortar's Lob is the bot's blind spot, not the
weapon's; the Glass has one hull by design; the Ghost takes no weapon
before level eight and so starts slow. Three ships that died at level one
before this pass (Anchor, Orbital, Ghost) now live.

```text
ship       >2m  >5m  >10m  >15m  >20m  kills/min
Claw       4/4  4/4   4/4   3/4   2/4      1237
Dart       4/4  4/4   3/4   1/4   1/4      1138
Hull       4/4  4/4   3/4   1/4   1/4       539
Prism      4/4  4/4   1/4   0/4   0/4       912
Halo       4/4  4/4   2/4   2/4   1/4       851
Needle     4/4  4/4   0/4   0/4   0/4       515
Sapper     4/4  4/4   3/4   0/4   0/4       994
Phase      3/4  3/4   0/4   0/4   0/4       605
Null       4/4  4/4   1/4   0/4   0/4       886
Lasher     4/4  2/4   1/4   1/4   0/4       532
Anchor     1/4  1/4   1/4   0/4   0/4       380
Carrier    4/4  4/4   2/4   2/4   1/4       884
Warden     4/4  4/4   0/4   0/4   0/4       474
Hawk       4/4  4/4   2/4   2/4   1/4      1129
Volt       2/4  2/4   0/4   0/4   0/4       460
Mortar     2/4  0/4   0/4   0/4   0/4       219
Brace      4/4  4/4   1/4   0/4   0/4       590
Sentry     4/4  4/4   1/4   1/4   0/4      1033
Lantern    4/4  4/4   2/4   1/4   0/4       876
Coil       4/4  4/4   2/4   2/4   1/4       381
Kestrel    4/4  4/4   1/4   1/4   0/4       887
Rampart    3/4  2/4   1/4   1/4   0/4       590
Orbital    3/4  2/4   1/4   0/4   0/4       174
Ghost      2/4  1/4   1/4   1/4   1/4        51
Glass      1/4  1/4   0/4   0/4   0/4       276
Mirror     4/4  4/4   1/4   1/4   0/4       811
```

## After the boss plan (six bosses, the jackpot, the bench), the bot, 2 seeds a ship

The first per-ship boss cadence, from `bosses 2`: the careful bot flies
the Field and every boss it meets is measured. Pool draws differ by seed,
so a ship meets the Lattice, Keeper or Bulwark only when a draw lands
them. The Warden column is the one to read: its hull now follows the
swarm's curve, and a build that cannot reach its back stalemates it for
minutes (Coil 900 s with a 239 s stretch of no damage; Orbital, Brace,
Carrier, the Warden ship, Lasher and Volt past 300 s). The Bulwark walls
the Hull and the Lasher for its whole horizon without killing them. These
are the boss balance pass's input: the bands in `boss_bands.w` hold for
the Claw, the Dart and the Hawk and no further yet.

```text
ship      boss      reached  killed  died   ttk   hull lost  no-damage streak  share
Claw      WARDEN        2/2       2     0    38s          0              0.8s     0%
Claw      LANCER        2/2       2     0    81s          1              0.7s     0%
Claw      HIVE          1/2       1     0    35s          0              0.1s     0%
Claw      BULWARK       1/2       1     0   259s          0                1s     0%
Dart      WARDEN        2/2       2     0    46s          0              0.7s     0%
Dart      LANCER        2/2       2     0    36s          0              0.4s     0%
Dart      HIVE      0/2
Dart      KEEPER        2/2       2     0    74s          3              0.3s     0%
Hull      WARDEN        2/2       1     1    68s         18              9.3s    10%
Hull      LANCER    0/2
Hull      HIVE      0/2
Hull      BULWARK       1/2       0     0   600s          0              4.5s     0%
Prism     WARDEN        2/2       2     0   107s          2              1.3s     0%
Prism     LANCER    0/2
Prism     HIVE      0/2
Halo      WARDEN        2/2       1     1    45s          6              3.3s    16%
Halo      LANCER    0/2
Halo      HIVE      0/2
Needle    WARDEN        2/2       1     1    29s          2              2.5s    13%
Needle    LANCER    0/2
Needle    HIVE      0/2
Sapper    WARDEN        2/2       2     0   112s          2             21.3s    10%
Sapper    LANCER    0/2
Sapper    HIVE      0/2
Phase     WARDEN        2/2       1     1    26s          1              1.7s     1%
Phase     LANCER    0/2
Phase     HIVE      0/2
Null      WARDEN        2/2       2     0    35s          0              1.3s     2%
Null      LANCER    0/2
Null      HIVE      0/2
Null      LATTICE       1/2       1     0    64s          2                1s     1%
Lasher    WARDEN        2/2       2     0   342s          0             10.2s    23%
Lasher    LANCER    0/2
Lasher    HIVE      0/2
Lasher    BULWARK       1/2       0     0   269s          0              7.7s     0%
Anchor    WARDEN    0/2
Anchor    LANCER    0/2
Anchor    HIVE      0/2
Carrier   WARDEN        2/2       0     1   500s          8              7.3s     0%
Carrier   LANCER    0/2
Carrier   HIVE      0/2
Warden    WARDEN        2/2       2     0   620s          1              7.1s     5%
Warden    LANCER        1/2       0     0   422s          7              3.8s     0%
Warden    HIVE      0/2
Warden    BULWARK       1/2       0     0   136s          0              6.5s     0%
Hawk      WARDEN        2/2       2     0    64s          1              0.9s     0%
Hawk      LANCER    0/2
Hawk      HIVE      0/2
Hawk      LATTICE       1/2       1     0    66s          3              0.2s     0%
Volt      WARDEN        2/2       1     1   333s          7             10.5s     8%
Volt      LANCER    0/2
Volt      HIVE      0/2
Mortar    WARDEN    0/2
Mortar    LANCER    0/2
Mortar    HIVE      0/2
Brace     WARDEN        2/2       1     0   548s          1             14.1s     6%
Brace     LANCER    0/2
Brace     HIVE      0/2
Sentry    WARDEN        2/2       2     0    40s          0              1.4s     2%
Sentry    LANCER        1/2       0     1   100s         14              0.3s     0%
Sentry    HIVE      0/2
Lantern   WARDEN        2/2       2     0   127s          2              1.4s     0%
Lantern   LANCER    0/2
Lantern   HIVE      0/2
Lantern   BULWARK       1/2       1     0   244s          8              0.5s     0%
Coil      WARDEN        2/2       0     0   900s          1            239.1s     0%
Coil      LANCER    0/2
Coil      HIVE      0/2
Kestrel   WARDEN        2/2       2     0    49s          1              0.9s     0%
Kestrel   LANCER    0/2
Kestrel   HIVE      0/2
Kestrel   LATTICE       1/2       1     0   241s          2              0.6s     0%
Rampart   WARDEN        1/2       1     0   130s          2             10.4s     9%
Rampart   LANCER    0/2
Rampart   HIVE      0/2
Orbital   WARDEN        2/2       1     0   700s          0             24.2s     7%
Orbital   LANCER    0/2
Orbital   HIVE      0/2
Orbital   LATTICE       1/2       0     0   398s          2              0.7s     0%
Ghost     WARDEN    0/2
Ghost     LANCER    0/2
Ghost     HIVE      0/2
Glass     WARDEN    0/2
Glass     LANCER    0/2
Glass     HIVE      0/2
Mirror    WARDEN        2/2       2     0    33s          0              1.1s     4%
Mirror    LANCER    0/2
Mirror    HIVE      0/2
```

## After the boss balance pass, the bot, 2 seeds a ship (encounters reached)

What the pass changed: the Warden's front is 0.6 and its hull a notch
lower; past desperation a boss's touch and shots grow by half a minute
(to three times) and the swarm comes back, so no fight stalls; the
Warden, the tutorial boss, turns desperate half again as late; the
careful bot orbits the Warden to its back, hugs a boss with a
short-range build, and never enters a boss's reach. Every fight the bot
reaches now ends, and `boss_bands_a.w` and `_b.w` hold the whole roster
at the floor the pass found (ends within eight minutes, no thirty-second
wait, no six-tenths idle), to tighten as the pilot improves.

What is left: the Warden kills the weakest early builds (Volt, Coil, the
Warden ship, in both seeds) — it was harmless before the hull curve and
is the first real test now; the Hull waits twenty seconds on it and
stands against the Bulwark for eight minutes before dying. Those are the
pilot's and the Hull's, not the bosses'.

```text
ship      boss      reached  killed  died   ttk   hull lost  no-damage streak  share
Claw      WARDEN        2/2       2     0    16s          1              0.8s     0%
Claw      LANCER        1/2       0     1    87s         15              1.5s     1%
Claw      KEEPER        1/2       0     1    86s         10              2.8s     3%
Claw      BULWARK       1/2       1     0    55s          0              0.4s     0%
Dart      WARDEN        2/2       2     0    18s          1              0.7s     0%
Dart      HIVE          1/2       1     0    42s          0                0s     0%
Dart      LATTICE       1/2       1     0    30s          0              0.5s     0%
Dart      BULWARK       2/2       2     0    60s          0              0.3s     0%
Hull      WARDEN        2/2       1     1   104s         21             22.6s    15%
Hull      BULWARK       1/2       0     1   465s         65              2.1s     2%
Prism     WARDEN        2/2       2     0    47s          0              1.2s     0%
Prism     BULWARK       1/2       0     1   101s          9              4.7s     4%
Halo      WARDEN        2/2       2     0    15s          0              2.4s     9%
Halo      LATTICE       1/2       1     0   145s          8              1.1s     0%
Halo      BULWARK       1/2       0     1    83s         21              3.2s     4%
Needle    WARDEN        2/2       1     1    25s          2              5.2s    26%
Sapper    WARDEN        2/2       2     0    36s          5              2.2s     5%
Sapper    LANCER        1/2       0     1    80s         15              3.6s     7%
Phase     WARDEN        2/2       2     0    65s          0              1.7s     4%
Phase     LANCER        1/2       0     1    82s          5              2.1s     2%
Null      WARDEN        2/2       2     0    16s          0              1.3s     3%
Null      LATTICE       1/2       0     1    84s         24              2.7s     1%
Lasher    WARDEN        2/2       1     1    38s          5              3.8s    10%
Carrier   WARDEN        2/2       1     1    83s          6              7.7s     3%
Carrier   HIVE          1/2       1     0    61s          0              1.2s     0%
Carrier   LATTICE       1/2       1     0    53s          0              0.9s     0%
Warden    WARDEN        2/2       0     2   140s         10                6s    12%
Hawk      WARDEN        2/2       2     0    27s          1              0.9s     0%
Hawk      LATTICE       1/2       1     0    55s          2              0.3s     0%
Volt      WARDEN        2/2       0     2    61s         10              2.7s     0%
Brace     WARDEN        2/2       1     1    98s          7                4s     3%
Sentry    WARDEN        2/2       2     0    20s          4              1.3s     2%
Sentry    BULWARK       1/2       0     1   100s         14              1.4s     2%
Lantern   WARDEN        2/2       2     0    45s          3              1.3s     0%
Lantern   LATTICE       1/2       0     1   115s         16              1.2s     1%
Coil      WARDEN        2/2       0     2   101s         10              2.8s    10%
Kestrel   WARDEN        2/2       2     0    14s          0              0.9s     0%
Kestrel   LANCER        1/2       0     1    80s         12              1.1s     0%
Rampart   WARDEN        1/2       1     0    32s          0              2.3s     6%
Orbital   WARDEN        2/2       2     0    42s          2              0.9s     0%
Mirror    WARDEN        2/2       2     0    15s          0              1.5s     3%
Mirror    LATTICE       1/2       1     0   146s          0              1.3s     0%
```

## After the Warden playtest: a human reaction for the bot, a tutorial boss that stings

Watched fights (`playtest Coil`, `playtest Volt`) showed the Warden too
hard: its spiral painted the screen, the Coil died at half the boss's
hull with four repairs lying unused, and the Volt died in six seconds
because the boss spawned beside it. Underneath: the careful bot decided
every eight milliseconds, so every number flown by it was tuned against
reflexes no player has.

The bot now decides every tenth of a second and holds its input between
decisions (`human` in pilots.w), picks up a repair when below half hull,
orbits the Warden to its back, and hugs a boss with a short-range build.
The Warden's spiral beats every sixth of a second at 160 px/s and stings
for one, the aimed fan for two; a boss arrives at the farthest of six
spawn points; the Warden turns desperate at twice the rule.

```text
ship    Warden, 2 seeds: reached killed died  ttk   hull lost
Claw                     2/2     2      0     20s   0
Hawk                     2/2     2      0     12s   1
Coil                     1/2     1      0    133s   4
Brace                    2/2     2      0    135s   2
Volt                     1/2     0      1    151s   6
```

With the human reaction the Claw reaches ten minutes in 4/4 and fifteen
in 1/4 at rank zero (it was 4/4 and 2/4 with instant reflexes). The
weapon and merge bands are unchanged: that bench flies a fixed circle.

## The boss overview: every ship forced into every boss, every weapon held against every boss

Two sweeps for the overview, after the human reaction. `bosses matrix 2`:
each ship with the boss forced into its own slot, two seeds, as
kills/deaths/reached and the mean time to kill. Most ships at rank zero
do not reach 10:00 with a human-paced pilot, so the later columns are
the ships that do. (The Warden's hull was raised a notch after this run:
its column is at 4300, the game's is 6450.)

```text
ship           WARDEN      LANCER        HIVE     LATTICE      KEEPER     BULWARK
           k/d/r  ttk  k/d/r  ttk  k/d/r  ttk  k/d/r  ttk  k/d/r  ttk  k/d/r  ttk
Claw      2/0/2   11s 1/1/2   89s 1/0/1   58s 2/0/2   65s 0/1/1  102s 0/2/2   90s
Dart      2/0/2    8s 2/0/2   50s 2/0/2   47s 2/0/2   34s 2/0/2   81s 2/0/2   80s
Hull      2/0/2   61s 1/0/1   24s 1/0/1   27s 1/0/1   17s 1/0/1   56s 1/0/1   36s
Prism     2/0/2   14s 1/0/1   57s 1/0/1   40s 1/0/1   36s 1/0/1   59s 1/0/1   64s
Halo      1/0/1   25s           -           -           -           -           -
Needle    1/1/2   89s 1/0/1   46s 1/0/1   31s 1/0/1   30s 1/0/1   50s 1/0/1   66s
Sapper    2/0/2   58s           -           -           -           -           -
Phase               -           -           -           -           -           -
Null      2/0/2   13s           -           -           -           -           -
Lasher    1/1/2   81s           -           -           -           -           -
Anchor    1/0/1   11s           -           -           -           -           -
Carrier   2/0/2   29s           -           -           -           -           -
Warden    2/0/2   83s 0/1/1   98s           - 0/1/1  146s           - 0/1/1  126s
Hawk      2/0/2   11s 1/0/1   38s 1/0/1   56s 1/0/1   25s 1/0/1  114s 1/0/1   53s
Volt      0/1/1  152s           -           -           -           -           -
Mortar    1/0/1   11s           -           -           -           -           -
Brace     2/0/2   85s           -           -           -           -           -
Sentry    2/0/2    9s           -           -           -           -           -
Lantern   1/1/2   87s           -           -           -           -           -
Coil      1/0/1   51s           -           -           -           -           -
Kestrel   1/0/1    8s           -           -           -           -           -
Rampart             -           -           -           -           -           -
Orbital   1/0/1   70s           -           -           -           -           -
Ghost               -           -           -           -           -           -
Glass               -           -           -           -           -           -
Mirror    2/0/2    9s 0/1/1   76s           - 1/0/1   52s           - 0/1/1  107s
total         33/4/37      7/3/10       7/0/7      9/1/10       6/1/7      6/4/10
```

`balance bosses 2`: every base weapon at V held 120 px from each boss
(behind the Warden, down the Keeper's sector), damage a second, an
unkillable hull, nothing else in the arena. A boss is a big hull, so a
ring, field or fan that overlaps it strikes four times as often as it
would a Block (BOSS_HIT_SHARE); the pulse weapons (Nova, Mines,
Shockwave, Arc, Lob, Sweep) stay swarm weapons and a build carries
them, as the matrix's Hull and Sapper rows show.

```text
weapon          WARDEN   LANCER     HIVE  LATTICE   KEEPER  BULWARK
Cannon             143      222      238      288      287      288
Orbit               14       40       11       84       84       84
Nova                36        7        0       16       16       16
Seeker             143      326      391      463      463      465
Lance              134       30       17       40       40       40
Mines               19        3        0        5        5        5
Arc                 14        8        4       11       11       11
Shard              143      175       20      389      283      267
Tether             143       78       24       63       63       67
Gravity Well         0        9        0      142      111        4
Drone              143      166       94      293      384      360
Lob                  0        0        0       10        0        0
Flak               143      179      121      268      332      320
Turret             143      287      244      527      571      553
Sweep               66       19        0       10        9       10
Tesla Field         99       21        0       30       30       30
Boomerang          143      259      183      547      430      445
Shockwave           22        6        0        8        8        8
Satellite           26       92       14      207      206      207
Repulsor            44       12        0       13       13       13
```
