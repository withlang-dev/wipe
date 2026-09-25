#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform sampler2D texture0;
uniform float threshold;
void main() {
    vec3 c = texture(texture0, fragTexCoord).rgb;
    float value = max(c.r, max(c.g,c.b));
    float knee = smoothstep(threshold-.18, threshold+.22, value);
    finalColor = vec4(c * knee, 1.0);
}
