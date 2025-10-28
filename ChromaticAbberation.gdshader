shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform bool enable_effect = true;

uniform float blur_strength : hint_range(0.0, 3.0) = 0.4;
uniform float chroma_offset : hint_range(0.0, 3.0) = 0.18; // half of previous
uniform float tint_warmth   : hint_range(0.8, 1.2) = 1.03;

void fragment() {
    if (!enable_effect) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        vec2 uv = SCREEN_UV;
        vec2 pixel = 1.0 / vec2(textureSize(screen_tex, 0));

        // Gentle 5-tap blur — crisp but slightly softened
        vec3 blurred = texture(screen_tex, uv).rgb * 0.75;
        blurred += texture(screen_tex, uv + vec2(pixel.x * blur_strength, 0.0)).rgb * 0.0625;
        blurred += texture(screen_tex, uv - vec2(pixel.x * blur_strength, 0.0)).rgb * 0.0625;
        blurred += texture(screen_tex, uv + vec2(0.0, pixel.y * blur_strength)).rgb * 0.0625;
        blurred += texture(screen_tex, uv - vec2(0.0, pixel.y * blur_strength)).rgb * 0.0625;

        // Micro-offset RGB channels (no radial stretch)
        vec2 offset = vec2(chroma_offset, chroma_offset) * pixel * 1.5;

        float r = texture(screen_tex, uv + offset).r;
        float g = texture(screen_tex, uv).g;
        float b = texture(screen_tex, uv - offset).b;

        vec3 final_col = mix(vec3(r, g, b), blurred, 0.25);
        final_col *= tint_warmth;

        COLOR = vec4(final_col, 1.0);
    }
}
