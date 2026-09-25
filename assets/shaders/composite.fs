#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform sampler2D texture0;
uniform sampler2D bloom;
uniform sampler2D wide;
void main() {
    vec3 core = texture(texture0, fragTexCoord).rgb;
    vec3 glow = texture(bloom, fragTexCoord).rgb;
    vec3 halo = texture(wide, fragTexCoord).rgb;
    vec3 color = core + glow * 1.5 + halo * 0.9;
    // Soft roll-off keeps overlapping glows from clipping to flat white.
    color = color / (1.0 + color * .12);
    vec2 p = fragTexCoord * 2.0 - 1.0;
    color *= 1.0 - .10 * dot(p,p);
    finalColor = vec4(color,1.0);
}
