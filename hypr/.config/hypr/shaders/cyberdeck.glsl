#version 300 es
precision mediump float;

in vec2 v_texcoord;
uniform sampler2D tex;

out vec4 fragColor;

// Cheap on purpose: one texture fetch, one dot product, one sin.
// 138 shaders in this directory are dead symlinks into a missing
// /usr/share/aether, so this one is self-contained.
//
// Two things only, because the effect has to survive being looked at all day:
// a vignette that pulls the eye to the middle, and scanlines faint enough to
// read text through. Time is deliberately not used: no flicker, no motion.
void main() {
    vec4 src = texture(tex, v_texcoord);
    vec3 c = src.rgb;

    // Vignette. 0 at centre, ~0.09 at the corner midpoint, ~0.18 at a corner.
    vec2 p = v_texcoord - 0.5;
    c *= 1.0 - dot(p, p) * 0.35;

    // One bright/dark cycle per two physical pixels, +/-4%.
    c *= 0.96 + 0.04 * sin(gl_FragCoord.y * 3.14159265);

    // Slight cool cast: reads as a screen rather than a photo filter.
    c *= vec3(0.97, 1.0, 1.03);

    fragColor = vec4(c, src.a);
}
