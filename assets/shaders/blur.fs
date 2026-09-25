#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform sampler2D texture0;
uniform vec2 direction;
void main() {
    vec3 c = texture(texture0,fragTexCoord).rgb * .1974;
    c += texture(texture0,fragTexCoord + direction*1.4118).rgb * .2969;
    c += texture(texture0,fragTexCoord - direction*1.4118).rgb * .2969;
    c += texture(texture0,fragTexCoord + direction*3.2941).rgb * .0945;
    c += texture(texture0,fragTexCoord - direction*3.2941).rgb * .0945;
    c += texture(texture0,fragTexCoord + direction*5.1765).rgb * .0104;
    c += texture(texture0,fragTexCoord - direction*5.1765).rgb * .0104;
    finalColor = vec4(c,1.0);
}
