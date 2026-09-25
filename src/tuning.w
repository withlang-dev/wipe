// Gameplay knobs live together. Presentation colors and geometry stay in
// presentation.w; changing these values never changes storage or ownership.
pub type Rules {
    player_speed: f64 = 265.0,
    max_health: i32 = 3,
    fire_interval: f64 = 1.0 / 7.0,
    bullet_speed: f64 = 940.0,
    bullet_lifetime: f64 = 1.6,
    enemy_speed: f64 = 83.0,
    enemy_speed_variation: f64 = 32.0,
    enemy_acceleration: f64 = 0.22,
    spawn_base: f64 = 1.5,
    spawn_growth: f64 = 0.2,
    spawn_max: f64 = 24.0,
    spawn_grace: f64 = 0.15,
    bullet_hit_radius: f64 = 17.0,
    contact_radius: f64 = 29.0,
    invulnerability: f64 = 0.7,
    damage_stop: f64 = 0.045,
    death_stop: f64 = 0.14,
}
