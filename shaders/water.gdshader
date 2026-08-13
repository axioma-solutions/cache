shader_type spatial;
render_mode cull_disabled;

uniform vec3 shallow_color : source_color = vec3(0.1, 0.4, 0.5);
uniform vec3 deep_color : source_color = vec3(0.0, 0.1, 0.2);
uniform float wave_speed : hint_range(0.1, 5.0) = 1.0;
uniform float wave_scale : hint_range(0.5, 50.0) = 10.0;
uniform float wave_strength : hint_range(0.0, 0.1) = 0.02;
uniform float specular_strength : hint_range(0.0, 2.0) = 0.8;
uniform float alpha : hint_range(0.0, 1.0) = 0.7;
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.02;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Hash for noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise (multiple octaves, fewer in distance)
float fbm(vec2 p, float time, float detail) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	int octaves = int(detail * 6.0);
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) break;
		value += amplitude * noise(p * frequency + time * wave_speed * (0.5 + float(i) * 0.3));
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
		frequency *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

// Wave offset from fbm
vec2 wave_offset(vec2 pos, float time) {
	float n1 = fbm(pos * wave_scale, time, 1.0);
	float n2 = fbm(pos * wave_scale + vec2(5.2, 1.3), time * 0.7, 1.0);
	return vec2(n1, n2) * wave_strength;
}

vec2 wave_offset_lod(vec2 pos, float time, float detail) {
	float n1 = fbm(pos * wave_scale, time, detail);
	float n2 = fbm(pos * wave_scale + vec2(5.2, 1.3), time * 0.7, detail);
	return vec2(n1, n2) * wave_strength;
}

// Fake normal from multiple wave layers
vec3 wave_normal(vec2 pos, float time) {
	float e = 0.01;
	float h_c = wave_offset(pos, time).x + wave_offset(pos, time).y;
	float h_x = wave_offset(pos + vec2(e, 0.0), time).x + wave_offset(pos + vec2(e, 0.0), time).y;
	float h_z = wave_offset(pos + vec2(0.0, e), time).x + wave_offset(pos + vec2(0.0, e), time).y;
	float dx = (h_x - h_c) / e;
	float dz = (h_z - h_c) / e;
	return normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	vec2 pos = world_pos.xz;
	float cam_dist = length((VIEW_MATRIX * vec4(world_pos, 1.0)).xyz);
	float detail = clamp(1.0 - (cam_dist - 30.0) / 100.0, 0.3, 1.0);

	// Distorted color mixing
	vec2 offset = wave_offset_lod(pos, TIME, detail);
	float pattern = sin((pos.x + offset.x) * 3.0) * cos((pos.y + offset.y) * 3.0) * 0.5 + 0.5;

	// Normals — transform world normal to view space
	vec3 world_normal = wave_normal(pos, TIME);
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	// Fresnel for edge transparency
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	// Refraction — distort what's behind the water
	vec2 refracted_uv = SCREEN_UV + world_normal.xz * refraction_strength;
	vec3 behind = texture(screen_texture, refracted_uv).rgb;

	// Blend refracted background with water color
	vec3 water_color = mix(deep_color, shallow_color, pattern);
	ALBEDO = mix(behind, water_color, mix(alpha, 1.0, fresnel));
	ALPHA = 1.0;

	// Surface properties
	METALLIC = 0.0;
	ROUGHNESS = 0.05;
	SPECULAR = specular_strength;
}
