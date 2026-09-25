#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform sampler2D texture0;
uniform vec2 direction;
void main() {
    vec3 c = texture(texture0,fragTexCoord).rgb * .227027;
    c += texture(texture0,fragTexCoord + direction*1.384615).rgb * .316216;
    c += texture(texture0,fragTexCoord - direction*1.384615).rgb * .316216;
    c += texture(texture0,fragTexCoord + direction*3.230769).rgb * .070270;
    c += texture(texture0,fragTexCoord - direction*3.230769).rgb * .070270;
    finalColor = vec4(c,1.0);
}
