shader_type canvas_item;

uniform float shimmer_speed : hint_range(0.0, 5.0) = 1.0;
uniform float shimmer_amount : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Diagonal light band sweeping across — darkens to 0.7 at trough, visible on white
	float band = sin(UV.x * 5.0 + TIME * shimmer_speed) * 0.5 + 0.5;
	float brightness = 1.0 - shimmer_amount + shimmer_amount * band;
	COLOR = vec4(tex.rgb * COLOR.rgb * brightness, tex.a * COLOR.a);
}
