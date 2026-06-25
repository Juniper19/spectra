shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float bloom_threshold = 0.15;
uniform float bloom_intensity = 2.0;
uniform float blur_size : hint_range(0.0, 10.0) = 3.0;
uniform vec3 tint_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.4;

vec3 sample_bloom(sampler2D tex, vec2 uv, vec2 pixel_size, float size) {
    vec3 bloom = vec3(0.0);
    float total = 0.0;
    
    for (int x = -4; x <= 4; x++) {
        for (int y = -4; y <= 4; y++) {
            float weight = exp(-float(x*x + y*y) / (2.0 * size));
            vec2 offset = vec2(float(x), float(y)) * pixel_size * size;
            vec3 col = texture(tex, uv + offset).rgb;
            // only bright parts contribute to bloom
            vec3 bright = max(col - bloom_threshold, vec3(0.0));
            bloom += bright * weight;
            total += weight;
        }
    }
    return bloom / total;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 base = texture(screen_texture, uv).rgb;
    
    // bloom pass
    vec2 pixel_size = SCREEN_PIXEL_SIZE;
    vec3 bloom = sample_bloom(screen_texture, uv, pixel_size, blur_size);
    
    // additive blend like the reference images
    vec3 result = base + bloom * bloom_intensity * tint_color;
    
    // vignette
    vec2 centered = uv * 2.0 - 1.0;
    float vignette = 1.0 - dot(centered, centered) * vignette_strength;
    result *= vignette;
    
    COLOR = vec4(result, 1.0);
}