//! expect-stdout: UAT passed: no hiding spots, walls hold
// Every map: a motionless ship in any arena corner, or tucked beside the
// corner of any wall, is reached by the swarm within thirty seconds. A spot
// the swarm cannot reach is an exploit (a bot once survived 34 minutes in
// one).
use game
use tuning
use loadout
use ships
use pilots

fn reached(stage: Stage, spot: V2) -> bool:
    var g = Game.new(stage.rules())
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    g.start(launch)
    // No weapons: the swarm must arrive, not be held off.
    g.build.weapons[0].level = 0
    g.max_health = 1000
    g.health = 1000
    g.player = g.clamp_to_arena(spot, 14.0)
    for _ in 0..(120 * 30):
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
        if g.hurt_event: return true
    false

fn main:
    var failures = 0
    for k in 0..STAGE_COUNT:
        let stage = stage_at(k)
        let r = stage.rules()
        var spots: Vec[V2] = Vec.new()
        spots.push(V2 { x: 20.0, y: 20.0 })
        spots.push(V2 { x: r.arena_width - 20.0, y: 20.0 })
        spots.push(V2 { x: 20.0, y: r.arena_height - 20.0 })
        spots.push(V2 { x: r.arena_width - 20.0, y: r.arena_height - 20.0 })
        for w in stage.walls():
            spots.push(V2 { x: w.x - 16.0, y: w.y - 16.0 })
            spots.push(V2 { x: w.x + w.w + 16.0, y: w.y + w.h + 16.0 })
        for spot in spots:
            if not reached(stage, spot):
                failures += 1
                print(f"{stage.name()}: a ship at {spot.x as i32},{spot.y as i32} is never reached")
    // Walls hold: nothing stands inside one.
    let maze = Game.new(Stage.Maze.rules())
    let inside = maze.clamp_to_arena(V2 { x: 420.0, y: 300.0 }, 14.0)
    assert(not maze.in_wall(inside))
    assert(failures == 0)
    print("UAT passed: no hiding spots, walls hold")
