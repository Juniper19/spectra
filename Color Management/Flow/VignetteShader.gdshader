shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec2 screen_size = vec2(textureSize(screen_tex, 0));
    vec2 uv = FRAGCOORD.xy / screen_size;
    vec2 center = vec2(0.5);

    float dist = distance(uv, center);
    float inner_radius = 0.3;
    float outer_radius = 0.75;
    float vignette = smoothstep(inner_radius, outer_radius, dist);

    vec4 scene_color = texture(screen_tex, uv);

    // Instead of blending *to black*, blend *toward the tint color*
    vec4 tinted_overlay = mix(vec4(1.0), color, vignette * intensity);
    COLOR = scene_color * tinted_overlay;
}
