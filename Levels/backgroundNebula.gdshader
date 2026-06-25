shader_type canvas_item;

uniform vec3 color_a : source_color = vec3(0.4, 0.1, 0.8);
uniform vec3 color_b : source_color = vec3(0.0, 0.2, 0.9);
uniform vec3 color_c : source_color = vec3(0.6, 0.0, 0.5);
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.35;
uniform float speed : hint_range(0.0, 1.0) = 0.15;

float smoothnoise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(i + vec2(1,0), vec2(127.1, 311.7))) * 43758.5453);
    float c = fract(sin(dot(i + vec2(0,1), vec2(127.1, 311.7))) * 43758.5453);
    float d = fract(sin(dot(i + vec2(1,1), vec2(127.1, 311.7))) * 43758.5453);
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * speed;
    
    float n1 = smoothnoise(uv * 2.5 + vec2(t, t * 0.4));
    float n2 = smoothnoise(uv * 1.8 + vec2(-t * 0.7, t * 0.3));
    float n3 = smoothnoise(uv * 3.2 + vec2(t * 0.5, -t * 0.6));
    
    vec3 col = mix(color_a, color_b, n1);
    col = mix(col, color_c, n2 * 0.6);
    col *= n3 * 0.5 + 0.5;
    
    vec3 bg = vec3(0.03, 0.03, 0.06);
    col = mix(bg, col, nebula_strength * (0.5 + 0.5 * sin(TIME * 0.3 + n1 * 6.0)));
    
    COLOR = vec4(col, 1.0);
}