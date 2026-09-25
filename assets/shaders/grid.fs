#version 330
out vec4 finalColor;
uniform vec4 ship;             // screen x/y, presentation time, trauma
uniform vec4 impulses[16];     // screen x/y, normalized age, radius
uniform float impulseCount;

float lattice(vec2 p, float spacing, float thickness) {
    vec2 d = abs(mod(p + spacing * .5, spacing) - spacing * .5);
    vec2 aa = max(fwidth(p), vec2(.8));
    vec2 lines = 1.0 - smoothstep(vec2(thickness), vec2(thickness) + aa, d);
    return max(lines.x, lines.y);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void main() {
    vec2 screen = vec2(gl_FragCoord.x, 800.0 - gl_FragCoord.y);
    if (screen.x < 24.0 || screen.x > 1256.0 || screen.y < 76.0 || screen.y > 772.0) {
        finalColor = vec4(.001,.002,.009,1.0); return;
    }
    vec2 p = screen;
    vec2 delta = p - ship.xy;
    float distance = length(delta);
    // A broad displacement around the ship gives the arena a fabric quality.
    p += delta / max(distance, 1.0) * exp(-distance * .008) *
         (9.0 + 2.0 * sin(distance * .025 - ship.z * 3.0));
    float energy = 0.0;
    for (int i = 0; i < 16; ++i) {
        if (float(i) >= impulseCount) break;
        vec4 source = impulses[i];
        vec2 d = screen - source.xy;
        float r = length(d);
        float wave = r - source.w * source.z * 4.0;
        float envelope = exp(-abs(wave) / 65.0) * (1.0 - source.z);
        p += d / max(r, 1.0) * sin(wave * .055) * envelope * 22.0;
        energy += envelope;
    }
    p += vec2(sin(p.y * .009 + ship.z * .4), cos(p.x * .011 - ship.z * .3)) * .65;
    float fine = lattice(p, 12.0, .18);
    float major = lattice(p, 60.0, .30);
    vec3 color = vec3(.0015,.003,.011) + vec3(.020,.045,.25) * fine + vec3(.018,.035,.15) * major;
    color += vec3(.012,.075,.24) * fine * min(energy, 1.8);
    // Seeded, sparse stars do not allocate or create gameplay entities.
    vec2 cell = floor(screen / 29.0);
    vec2 local = fract(screen / 29.0) - vec2(hash(cell),hash(cell+19.0));
    float star = exp(-dot(local,local) * 12000.0) * step(.78, hash(cell+71.0));
    color += vec3(.48,.62,.72) * star * (.7 + .3*sin(ship.z + hash(cell)*6.28));
    finalColor = vec4(color,1.0);
}
