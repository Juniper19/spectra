shader_type canvas_item;

uniform vec4 outline_color : source_color;
uniform float tolerance = 0.1;
uniform float glow_intensity = 0.3;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    bool is_outline = tex_color.r < tolerance && tex_color.g < tolerance && tex_color.b < tolerance && tex_color.a > 0.0;
    bool is_white = tex_color.r > 0.9 && tex_color.g > 0.9 && tex_color.b > 0.9 && tex_color.a > 0.0;

    if (is_outline) {
        COLOR = vec4(0.0, 0.0, 0.0, tex_color.a);
    } else if (is_white) {
        vec3 glow = outline_color.rgb * glow_intensity;
        COLOR = vec4(outline_color.rgb + glow, tex_color.a);
    } else {
        discard;
    }
}
