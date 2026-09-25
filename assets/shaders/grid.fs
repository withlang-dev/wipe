#version 330
out vec4 finalColor;
uniform vec4 ship;             // screen x/y, presentation time, trauma
uniform vec4 impulses[16];     // screen x/y, normalized age, radius
uniform float impulseCount;
uniform vec4 bullets[24];      // screen x/y, unit direction
uniform float bulletCount;

float lattice(vec2 p, float spacing, float thickness) {
    vec2 d = abs(mod(p + spacing * .5, spacing) - spacing * .5);
    vec2 aa = max(fwidth(p), vec2(.9));
    vec2 lines = 1.0 - smoothstep(vec2(thickness), vec2(thickness) + aa, d);
    return max(lines.x, lines.y);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }

// Seeded, layered starfield; no allocation and no gameplay entities.
vec3 stars(vec2 screen, float time) {
    vec3 color = vec3(0.0);
    for (int layer = 0; layer < 2; ++layer) {
        float size = layer == 0 ? 15.0 : 37.0;
        vec2 cell = floor(screen / size);
        vec2 seed = cell + float(layer) * 53.0;
        vec2 center = vec2(hash(seed), hash(seed + 19.0));
        vec2 local = (fract(screen / size) - center) * size;
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
    vec2 screen = vec2(gl_FragCoord.x, 800.0 - gl_FragCoord.y);
    vec3 color = vec3(.002,.003,.012) + stars(screen, ship.z);
    if (screen.x < 24.0 || screen.x > 1256.0 || screen.y < 76.0 || screen.y > 772.0) {
        finalColor = vec4(color, 1.0); return;
    }
    vec2 p = screen;
    // The ship sits in a gravity well: lines are drawn toward it.
    vec2 delta = p - ship.xy;
    float distance = length(delta);
    float well = 26.0 * (distance / 70.0) * exp(1.0 - distance / 70.0);
    p += delta / max(distance, 1.0) * well * (1.0 + .08 * sin(ship.z * 6.0));
    float energy = 0.0;
    // Explosions push a ring outward through the fabric.
    for (int i = 0; i < 16; ++i) {
        if (float(i) >= impulseCount) break;
        vec4 source = impulses[i];
        vec2 d = screen - source.xy;
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
        vec2 d = screen - b.xy;
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
    // Gentle blue haze keeps the arena from reading as flat black.
    vec2 q = (screen - vec2(640.0, 424.0)) / vec2(640.0, 400.0);
    color += vec3(.006,.010,.035) * (1.0 - .6 * dot(q, q));
    finalColor = vec4(color, 1.0);
}
