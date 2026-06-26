shader_type canvas_item;

uniform float shimmer_speed : hint_range(0.0, 5.0) = 0.6;
uniform float shimmer_amount : hint_range(0.0, 0.5) = 0.18;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float wave = sin((UV.x + UV.y) * 3.0 + TIME * shimmer_speed) * 0.5 + 0.5;
	// Oscillates between (1 - amount) and 1.0 — visible as a dim/bright sweep on white
	float brightness = (1.0 - shimmer_amount) + shimmer_amount * wave;
	COLOR = vec4(tex.rgb * COLOR.rgb * brightness, tex.a * COLOR.a);
}
