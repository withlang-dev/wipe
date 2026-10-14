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

