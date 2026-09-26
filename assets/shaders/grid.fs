#version 330
out vec4 finalColor;
uniform vec4 ship;             // screen x/y, presentation time, trauma
uniform vec4 camera;           // world origin x/y of the screen, arena width/height
uniform vec4 impulses[16];     // screen x/y, normalized age, radius
uniform float impulseCount;
uniform vec4 bullets[24];      // screen x/y, unit direction
uniform float bulletCount;
uniform float shipVisible;     // 0 hides the gravity well (menus, death)
uniform vec2 stage;            // dead-center radius, camera zoom

float lattice(vec2 p, float spacing, float thickness) {
    vec2 d = abs(mod(p + spacing * .5, spacing) - spacing * .5);
    vec2 aa = max(fwidth(p), vec2(.9));
    vec2 lines = 1.0 - smoothstep(vec2(thickness), vec2(thickness) + aa, d);
    return max(lines.x, lines.y);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }

// Seeded, layered starfield in world space with slight parallax.
vec3 stars(vec2 world, float time) {
    vec3 color = vec3(0.0);
    for (int layer = 0; layer < 2; ++layer) {
        float size = layer == 0 ? 15.0 : 37.0;
        vec2 cell = floor(world / size);
        vec2 seed = cell + float(layer) * 53.0;
        vec2 center = vec2(hash(seed), hash(seed + 19.0));
        vec2 local = (fract(world / size) - center) * size;
        float density = layer == 0 ? .62 : .35;
        float present = step(density, hash(seed + 71.0));
        float radius = layer == 0 ? .55 : 1.1;
        float glow = exp(-dot(local, local) / radius);
        float twinkle = .55 + .45 * sin(time * (1.5 + hash(seed + 5.0) * 3.0) + hash(seed) * 6.28);
        vec3 hue = mix(vec3(.55,.68,1.0), vec3(1.0,.95,.85), hash(seed + 9.0));
        color += hue * glow * present * twinkle * (layer == 0 ? .8 : 1.2);
    }
    return color;
}

void main() {
    vec2 raw = vec2(gl_FragCoord.x, 800.0 - gl_FragCoord.y);
    // Zoom about the screen center; every screen-space input is pre-zoomed.
    vec2 screen = (raw - vec2(640.0, 400.0)) / stage.y + vec2(640.0, 400.0);
    vec2 world = screen + camera.xy;
    vec3 color = vec3(.002,.003,.012) + stars(world * .6 + camera.xy * .4, ship.z);
    bool inVoid = stage.x > 0.0 && length(world - camera.zw * .5) < stage.x;
    if (world.x < 0.0 || world.x > camera.z || world.y < 0.0 || world.y > camera.w || inVoid) {
        // Beyond the containment edge: stars only, dimmed toward the void.
        finalColor = vec4(color * .7, 1.0); return;
    }
    vec2 p = world;
    // The ship sits in a gravity well: lines are drawn toward it.
    vec2 delta = raw - ship.xy;
    float distance = length(delta);
    float well = 26.0 * (distance / 70.0) * exp(1.0 - distance / 70.0) * shipVisible;
    p += delta / max(distance, 1.0) * well * (1.0 + .08 * sin(ship.z * 6.0));
    float energy = 0.0;
    // Explosions push a ring outward through the fabric.
    for (int i = 0; i < 16; ++i) {
        if (float(i) >= impulseCount) break;
        vec4 source = impulses[i];
        vec2 d = raw - source.xy;
        float r = length(d);
        float wave = r - source.w * source.z * 4.5;
        float envelope = exp(-abs(wave) / 70.0) * (1.0 - source.z);
        p -= d / max(r, 1.0) * (sin(wave * .05) * .5 + .8) * envelope * 30.0;
        energy += envelope;
    }
    // Bullets drag a small wake with them.
    for (int i = 0; i < 24; ++i) {
        if (float(i) >= bulletCount) break;
        vec4 b = bullets[i];
        vec2 d = raw - b.xy;
        float r = length(d);
        float behind = max(0.0, -dot(d, b.zw));
        float pull = exp(-r / 26.0) * 7.0 + exp(-(r - behind) / 9.0) * exp(-behind / 60.0) * 2.5;
        p += d / max(r, 1.0) * pull;
        energy += exp(-r / 30.0) * .6;
    }
    p += vec2(sin(p.y * .012 + ship.z * .5), cos(p.x * .010 - ship.z * .35)) * 1.1;
    float fine = lattice(p, 20.0, .45);
    float major = lattice(p, 80.0, .75);
    vec3 fineColor = vec3(.028,.052,.32);
    vec3 majorColor = vec3(.055,.10,.52);
    color += fineColor * fine + majorColor * major;
    color += vec3(.22,.38,1.0) * max(fine, major) * min(energy, 1.4);
    // Gentle blue haze keeps the arena from reading as flat black; it
    // brightens toward the containment edge so the wall reads at a distance.
    vec2 q = (world - camera.zw * .5) / (camera.zw * .5);
    float edge = pow(max(abs(q.x), abs(q.y)), 6.0);
    color += vec3(.006,.010,.035) * (1.0 - .6 * dot(q, q)) + vec3(.02,.06,.16) * edge;
    finalColor = vec4(color, 1.0);
}
