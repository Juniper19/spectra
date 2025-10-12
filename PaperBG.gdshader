shader_type canvas_item;

uniform float bleed = 0.002;

void fragment() {
    // pull UVs slightly inward so sampling never hits the border pixels
    vec2 uv = clamp(UV, bleed, 1.0 - bleed);
    COLOR = texture(TEXTURE, uv);
}
