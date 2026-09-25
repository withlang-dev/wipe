#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform sampler2D texture0;
uniform sampler2D bloom;
void main() {
    vec3 core = texture(texture0, fragTexCoord).rgb;
    vec3 glow = texture(bloom, fragTexCoord).rgb;
    vec3 color = core + glow * 1.75;
    // Very mild edge falloff; white-hot cores remain white rather than gray.
    vec2 p = fragTexCoord * 2.0 - 1.0;
    color *= 1.0 - .09 * dot(p,p);
    finalColor = vec4(color,1.0);
}
