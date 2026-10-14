//! expect-stdout: UAT passed: fewer and tougher, the XP curve held, ranks a run apart
use game
use tuning
use pilots
use account
use ships
use save

// The careful Claw's level as each mark passes, over four seeds: every
// seed reaches 5:00; the ten-minute level is the survivors' (none means
// the bot died early on every seed, which the survival marks catch).
fn levels_at() -> (i32, i32):
    var five = 0
    var ten = 0
    var reached = 0
    for seed in 0..4:
        var g = test_game(.Claw, seed)
        var at_five = 0
        var at_ten = 0
        while g.phase != .Over and g.elapsed < 601.0:
            g.clear_events()
            g.tick(controls(&g, .Careful), 1.0 / 120.0)
            if at_five == 0 and g.elapsed >= 300.0: at_five = g.level
            if at_ten == 0 and g.elapsed >= 600.0: at_ten = g.level
            var guard = 0
            while g.phase == .Boost and guard < 20:
                guard += 1
                g.cache_reveal = 0.0
                g.choose(pick_card(&g))
        if at_five == 0: at_five = g.level
        five += at_five
        if at_ten > 0:
            ten += at_ten
            reached += 1
    (five / 4, if reached > 0: ten / reached else: 0)

fn main:
    // A Block has 2 hull by 1:30, 4 by 3:00, 8 by 5:00, 28 by 10:00: damage
    // and fire rate matter from minute two.
    assert(Kind.Block.base_hp(0.0) == 1)
    assert(Kind.Block.base_hp(1.5) == 2)
    assert(Kind.Block.base_hp(3.0) == 4)
    assert(Kind.Block.base_hp(5.0) == 8)
    assert(Kind.Block.base_hp(10.0) >= 26 and Kind.Block.base_hp(10.0) <= 30)
    // Fewer of them: the floor and the trickle at ten and twenty minutes are
    // well under what they were (182 and 462 alive; 5.2 and 10.2 a second).
    let r = Rules {}
    assert(r.minimum_alive(10.0) < 130.0 and r.minimum_alive(20.0) < 280.0)
    assert(r.spawn_rate(10.0) < 4.0 and r.spawn_rate(20.0) < 7.0)
    // XP follows health: a kill is worth more as enemies toughen, capped.
    assert(r.xp_per_hp > 0.0 and r.xp_hp_cap >= 2.0)
    // The level curve holds where the bot tuned it: 13 at 5:00 and 19 at
    // 10:00 before the change, within a level or two now.
    let (five, ten) = levels_at()
    assert(five >= 10 and five <= 15)
    assert(ten == 0 or (ten >= 16 and ten <= 25))
    // Ranks: +35% for the first five of an item, +60% after; hull, armor
    // and a reboot lead the shop.
    assert(ShopItem.Health.price(0) == 360 and ShopItem.Health.price(1) == 480 and ShopItem.Health.price(2) == 650)
    assert(ShopItem.Damage.price(5) == 1790 and ShopItem.Damage.price(6) == 2860)
    assert(shop_display_at(0) == .Health and shop_display_at(1) == .Armor and shop_display_at(2) == .Reboots)
    print("UAT passed: fewer and tougher, the XP curve held, ranks a run apart")
