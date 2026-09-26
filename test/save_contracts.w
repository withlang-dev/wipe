//! expect-stdout: UAT passed: save round trip, atomic backup, restore, set-aside, newer refusal, shop, unlocks, run record
use std.fs
use std.process.env
use std.process.set_env
use std.process.pid
use save
use account
use game
use ships
use loadout
use tuning

fn near(actual: f64, expected: f64):
    assert(actual > expected - 0.01 and actual < expected + 0.01)

fn main:
    let id = pid()
    let dir = f"/tmp/wipe-save-test-{id}"
    let _ = remove_tree(dir)
    let _ = set_env("WIPE_SAVE_DIR", dir)
    // A missing file is the new-player path, silently.
    var file = SaveFile.open()
    let (fresh, notice) = file.load()
    assert(notice == .Fresh and fresh.credits == 0)
    // Round trip every field kind.
    var s = Save { credits: 1988, spent: 700, runs: 12, seconds: 4321.5, no_reboot_clear: true }
    s.ranks[3] = 2
    s.best_time[4] = 1152.25
    s.cleared[2] = true
    s.taken_weapons[9] = true
    s.registry_kills[5] = 77
    s.registry_first[5] = 12.5
    s.volume = 0.4
    assert(file.store(&s))
    let (back, loaded) = file.load()
    assert(loaded == .Loaded)
    assert(back.credits == 1988 and back.spent == 700 and back.ranks[3] == 2 and back.runs == 12)
    near(back.seconds, 4321.5)
    near(back.best_time[4], 1152.25)
    assert(back.cleared[2] and back.taken_weapons[9] and back.no_reboot_clear)
    assert(back.registry_kills[5] == 77)
    near(back.registry_first[5], 12.5)
    near(back.volume, 0.4)
    // A second write keeps the first as the backup.
    var s2 = back
    s2.credits = 5
    assert(file.store(&s2))
    assert(file_exists(file.backup))
    // A corrupt primary restores from the backup and says so.
    let _ = write_file(file.path, "garbage without a version")
    let (restored, why) = file.load()
    assert(why == .Restored and restored.credits == 1988)
    // Both unreadable: both are set aside, never deleted, and play starts fresh.
    let _ = write_file(file.path, "nonsense")
    let _ = write_file(file.backup, "nonsense")
    let (empty, aside) = file.load()
    assert(aside == .SetAside and empty.credits == 0)
    assert(not file_exists(file.path) and not file_exists(file.backup))
    assert(list_files_text(dir).find("unreadable") >= 0)
    // A newer format is refused and never overwritten.
    let _ = write_file(file.path, "version 99\ncredits 50\n")
    var newer = SaveFile.open()
    let (_, too_new) = newer.load()
    match too_new:
        .TooNew(v) => assert(v == 99)
        _ => assert(false)
    assert(not newer.store(&s))
    match read_file(newer.path):
        Ok(text) => assert(text.starts_with("version 99"))
        Err(_) => assert(false)
    // Floats parse the way the file writes them.
    near(parse_float("19.500"), 19.5)
    near(parse_float("-3.25"), -3.25)
    near(parse_float("7"), 7.0)
    // Shop prices escalate and ranks feed the run.
    assert(ShopItem.Damage.price(0) == 200 and ShopItem.Damage.price(1) == 320)
    var ranked = Save {}
    ranked.ranks[0] = 2
    ranked.ranks[7] = 1
    let mods = shop_mods(&ranked)
    near(mods.damage, 1.1)
    assert(mods.armor == 1)
    // Unlocks read run facts; the Dart opens at five minutes.
    var progress_save = Save {}
    assert(not ship_unlocked(.Dart, &progress_save))
    progress_save.best_time[0] = 301.0
    assert(ship_unlocked(.Dart, &progress_save))
    assert(ship_unlocked(.Claw, &progress_save))
    // Recording a run banks credits, updates bests, and feeds the registry.
    var g = Game.new()
    g.elapsed = 400.0
    g.credits = 120
    g.kills = 50
    g.kills_by_kind[2] = 50
    let (after, new_best) = record_run(Save {}, &g)
    assert(new_best and after.credits == 120 and after.runs == 1 and after.kills == 50)
    near(after.best_time[0], 400.0)
    assert(after.registry_kills[2] == 50)
    let ships = new_ships(&Save {}, &after)
    assert(ships.len() == 1 and ships[0] == Ship.Dart)
    assert(next_rank(&after).is_some())
    let _ = remove_tree(dir)
    print("UAT passed: save round trip, atomic backup, restore, set-aside, newer refusal, shop, unlocks, run record")
