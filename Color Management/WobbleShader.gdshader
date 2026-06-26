shader_type canvas_item;

uniform float shimmer_speed : hint_range(0.0, 5.0) = 0.6;
uniform float shimmer_amount : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float wave = sin((UV.x + UV.y) * 3.0 + TIME * shimmer_speed) * 0.5 + 0.5;
	float brightness = 1.0 + wave * shimmer_amount;
	COLOR = vec4(tex.rgb * brightness, tex.a);
}
