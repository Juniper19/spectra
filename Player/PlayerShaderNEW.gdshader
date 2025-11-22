shader_type canvas_item;

uniform vec4 tint_color : source_color;

void fragment() {
    vec4 c = texture(TEXTURE, UV);

    // How "white" the pixel is (1 = white, 0 = dark)
    float brightness = dot(c.rgb, vec3(0.3333));

    // Pixels near pure white should be recolored
    float mask = smoothstep(0.75, 1.0, brightness);

    // Preserve alpha
    vec4 recolored = vec4(tint_color.rgb, c.a);

    // Mix only where mask is strong
    COLOR = mix(c, recolored, mask);
}
