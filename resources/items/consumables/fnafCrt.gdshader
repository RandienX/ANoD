// CRT Shader for Godot Engine (Minimal Brightness - Cosine Scanlines Version)
// Simulates old CRT displays using crisp cosine-based scanlines
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;

// Base resolution for pixel-perfect effects
uniform vec2 resolution = vec2(864.0, 648.0);
uniform float brightness : hint_range(0.0, 1.0) = 0.9;

// ===== Effect Controls =====

// NEW: Cosine-based scanlines (replaces old Gaussian scanlines)
uniform float scanline_amount : hint_range(0.0, 1.0) = 0.8;
uniform float scanline_count : hint_range(0.0, 1000.0) = 120.0;
uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.25;

// Screen curvature/warp effect
uniform float warp_amount : hint_range(0.0, 5.0) = 0.1;

// Visual noise/interference
uniform float noise_amount : hint_range(0.0, 0.8) = 0.03;
uniform float interference_amount : hint_range(0.0, 1.0) = 0.2;

// Shadow mask/grille (simulates color phosphor patterns)
uniform float grille_amount : hint_range(0.0, 1.0) = 0.1;
uniform float grille_size : hint_range(1.0, 5.0) = 1.0;

// Vignette (darkening at screen edges)
uniform float vignette_amount : hint_range(0.0, 2.0) = 0.6;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;

// Chromatic aberration (color separation)
uniform float aberation_amount : hint_range(0.0, 1.0) = 0.5;

// Rolling line effect (simulates VHS/analog interference)
uniform float roll_line_amount : hint_range(0.0, 1.0) = 0.3;
uniform float roll_speed : hint_range(-8.0, 8.0) = 1.0;

// Pixel sharpness/softness (horizontal filtering only)
uniform float pixel_strength : hint_range(-4.0, 0.0) = -2.0;

// ===== Utility Functions =====

float random(vec2 uv) {
    return fract(cos(uv.x * 83.4827 + uv.y * 92.2842) * 43758.5453123);
}

vec3 fetch_pixel(vec2 uv, vec2 off) {
    vec2 pos = floor(uv * resolution + off) / resolution + vec2(0.5) / resolution;
    float noise = 0.0;
    if (noise_amount > 0.0) {
        noise = random(pos + fract(TIME)) * noise_amount;
    }
    if (max(abs(pos.x - 0.5), abs(pos.y - 0.5)) > 0.5) {
        return vec3(0.0);
    }
    return texture(SCREEN_TEXTURE, pos, -16.0).rgb + noise;
}

vec2 Dist(vec2 pos) {
    pos = pos * resolution;
    return -((pos - floor(pos)) - vec2(0.5));
}

float Gaus(float pos, float scale) {
    return exp2(scale * pos * pos);
}

// Horizontal 3-tap Gaussian filter (vertical scanlines handled separately now)
vec3 Horz3(vec2 pos, float off) {
    vec3 b = fetch_pixel(pos, vec2(-1.0, off));
    vec3 c = fetch_pixel(pos, vec2( 0.0, off));
    vec3 d = fetch_pixel(pos, vec2( 1.0, off));
    float dst = Dist(pos).x;
    float wb = Gaus(dst - 1.0, pixel_strength);
    float wc = Gaus(dst + 0.0, pixel_strength);
    float wd = Gaus(dst + 1.0, pixel_strength);
    return (b * wb + c * wc + d * wd) / (wb + wc + wd);
}

// Simplified Tri() - horizontal filtering only, no vertical Gaussian blending
vec3 Tri(vec2 pos) {
    return Horz3(pos, 0.0);
}

vec2 warp(vec2 uv) {
    vec2 delta = uv - 0.5;
    float delta2 = dot(delta.xy, delta.xy);
    float delta4 = delta2 * delta2;
    float delta_offset = delta4 * warp_amount;
    vec2 warped = uv + delta * delta_offset;
    return (warped - 0.5) / mix(1.0, 1.2, warp_amount/5.0) + 0.5;
}

float vignette(vec2 uv) {
    uv *= 1.0 - uv.xy;
    float v = uv.x * uv.y * 15.0;
    return pow(v, vignette_intensity * vignette_amount);
}

vec3 grille(vec2 uv) {
    float unit = PI / 3.0;
    float scale = 2.0 * unit / grille_size;
    float r = smoothstep(0.5, 0.8, cos(uv.x * scale - unit));
    float g = smoothstep(0.5, 0.8, cos(uv.x * scale + unit));
    float b = smoothstep(0.5, 0.8, cos(uv.x * scale + 3.0 * unit));
    return mix(vec3(1.0), vec3(r, g, b), grille_amount);
}

float roll_line(vec2 uv) {
    float x = uv.y * 3.0 - TIME * roll_speed;
    float f = cos(x) * cos(x * 2.35 + 1.1) * cos(x * 4.45 + 2.3);
    float rl = smoothstep(0.5, 0.9, f);
    return rl * roll_line_amount;
}

// ===== NEW SCANLINES: Cosine-based pattern =====
float apply_cosine_scanlines(vec2 uv, vec3 color) {
    // Crisp cosine wave pattern for evenly-spaced horizontal lines
    float scan = 0.5 + 0.5 * cos(uv.y * scanline_count * PI);
    // Mix original color with darkened version based on scanline pattern
    return scan;
}

void fragment() {
    vec2 pix = FRAGCOORD.xy;
    vec2 pos = warp(SCREEN_UV);

    // Rolling interference lines
    float line = 0.0;
    if (roll_line_amount > 0.0) {
        line = roll_line(pos);
    }

    // Horizontal interference/jitter
    vec2 sq_pix = floor(pos * resolution) / resolution + vec2(0.5) / resolution;
    if (interference_amount + roll_line_amount > 0.0) {
        float interference = random(sq_pix.yy + fract(TIME));
        pos.x += (interference * (interference_amount + line * 6.0)) / resolution.x;
    }

    // Base color with horizontal pixel filtering only
    vec3 clr = Tri(pos);

    // ===== APPLY NEW COSINE SCANLINES =====
    if (scanline_amount > 0.0) {
        float scan_factor = apply_cosine_scanlines(pos, clr);
        clr *= mix(1.0, scan_factor, scanline_amount);
    }

    // Chromatic aberration (color separation)
    if (aberation_amount > 0.0) {
        float chromatic = aberation_amount + line * 2.0;
        vec2 chromatic_x = vec2(chromatic, 0.0) / resolution.x;
        vec2 chromatic_y = vec2(0.0, chromatic/2.0) / resolution.y;
        float r = Tri(pos - chromatic_x).r;
        float g = Tri(pos + chromatic_y).g;
        float b = Tri(pos + chromatic_x).b;
        clr = vec3(r, g, b);
    }

    // Shadow mask/grille
    if (grille_amount > 0.0) {
        clr *= grille(pix);
    }

    // Minimal brightness adjustment (preserves original tone)
    clr *= brightness + line * 3.0 + grille_amount * 2.0;

    // Vignette (darken edges)
    if (vignette_amount > 0.0) {
        clr *= vignette(pos);
    }

    COLOR.rgb = clr;
    COLOR.a = 1.0;
}