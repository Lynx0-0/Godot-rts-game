// Shader per simulare profondità di campo e focus centrale
shader_type canvas_item;

uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_smoothness : hint_range(0.0, 1.0) = 0.5;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform vec2 focus_center = vec2(0.5, 0.5);
uniform float focus_radius : hint_range(0.0, 1.0) = 0.3;

// Funzione per blur semplice
vec4 blur(sampler2D tex, vec2 uv, vec2 pixel_size, float amount) {
    vec4 color = vec4(0.0);
    float total = 0.0;
    
    for(float x = -2.0; x <= 2.0; x++) {
        for(float y = -2.0; y <= 2.0; y++) {
            vec2 offset = vec2(x, y) * pixel_size * amount;
            color += texture(tex, uv + offset);
            total += 1.0;
        }
    }
    
    return color / total;
}

void fragment() {
    vec2 uv = UV;
    vec4 color = texture(TEXTURE, uv);
    
    // Calcola distanza dal centro focus
    float dist = distance(uv, focus_center);
    
    // Vignette effect
    float vignette = smoothstep(1.0 - vignette_smoothness, 1.0, 1.0 - dist * vignette_intensity * 2.0);
    
    // Depth blur basato su distanza dal focus
    float blur_factor = smoothstep(focus_radius, 1.0, dist) * blur_amount;
    
    if(blur_factor > 0.1) {
        color = blur(TEXTURE, uv, TEXTURE_PIXEL_SIZE, blur_factor);
    }
    
    // Applica vignette
    color.rgb *= vignette;
    
    // Aumenta contrasto e luminosità al centro
    float center_boost = 1.0 - smoothstep(0.0, focus_radius * 2.0, dist);
    color.rgb = mix(color.rgb, color.rgb * 1.2, center_boost * 0.3);
    
    COLOR = color;
}
