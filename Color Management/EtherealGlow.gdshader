shader_type canvas_item;

uniform float pulse_speed : hint_range(0.5, 10.0) = 2.2;
uniform float glow_amount : hint_range(0.0, 2.0) = 0.65;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	COLOR = vec4(tex.rgb * COLOR.rgb * (1.0 + glow_amount * pulse), tex.a * COLOR.a);
}
