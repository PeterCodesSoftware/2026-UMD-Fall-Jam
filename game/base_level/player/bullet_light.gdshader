shader_type canvas_item;
render_mode unshaded, blend_mix;

// Per-instance radius keeps all three charge sizes on one shared material.
instance uniform float core_radius : hint_range(1.0, 10.0, 0.5) = 2.0;
// One logical pixel matches the sprite-art grid (5 display pixels at 1280x720).
uniform float pixel_size : hint_range(0.25, 4.0, 0.25) = 1.0;
uniform float glow_width : hint_range(0.0, 5.0, 0.25) = 3.0;
uniform float smoke_speed : hint_range(0.0, 3.0, 0.05) = 0.8;
uniform float glow_opacity : hint_range(0.0, 1.0) = 0.9;
uniform vec3 smoke_tint : source_color = vec3(0.4, 0.65, 1.0);
uniform vec4 inner_smoke_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	// Quantize in screen space, then convert that cell center back to local
	// coordinates. Pixel blocks stay axis-aligned even when this node rotates.
	vec2 local_dx = dFdx(local_position);
	vec2 local_dy = dFdy(local_position);
	float units_per_screen_pixel = max(length(vec2(local_dx.x, local_dy.x)), 0.00001);
	float block_size = max(floor(pixel_size / units_per_screen_pixel + 0.5), 1.0);
	vec2 screen_position = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 cell_center = (floor(screen_position / block_size) + 0.5) * block_size;
	vec2 offset = cell_center - screen_position;
	vec2 p = local_position + local_dx * offset.x + local_dy * offset.y;

	float distance_from_center = length(p);
	float core = 1.0 - step(core_radius, distance_from_center);
	// A turbulent inner haze feeds translucent puffs that expand away from
	// the core, drift upward, and dissolve before their emission cycle resets.
	float time = TIME * smoke_speed;
	vec2 flow = p * 0.6 + vec2(time * 0.35, time * 0.8);
	float turbulence = noise(flow) * 0.65 + noise(flow * 1.9 - time * 0.4) * 0.35;
	float envelope = 1.0 - smoothstep(core_radius, core_radius + max(glow_width * 1.5, 0.001), distance_from_center);
	float smoke = envelope * (0.25 + 0.75 * smoothstep(0.25, 0.8, turbulence));
	for (int i = 0; i < 6; i++) {
		float cycle = time * 0.65 + float(i) / 6.0;
		float age = fract(cycle);
		float seed = float(i) * 13.7 + floor(cycle) * 9.3;
		float angle = hash(vec2(seed, 4.1)) * 6.2831853 + sin(time + seed) * 0.4;
		vec2 direction = vec2(cos(angle), sin(angle));
		vec2 center = direction * (core_radius + age * glow_width * 1.8);
		center.y -= age * glow_width * 0.65;
		float puff_radius = max(glow_width * (0.35 + 0.65 * age), 0.001);
		float puff = 1.0 - smoothstep(puff_radius * 0.2, puff_radius, length(p - center));
		float dissolve = sin(age * 3.14159265) * (1.0 - age);
		smoke = max(smoke, puff * dissolve * (0.6 + turbulence * 0.4));
	}
	// Quantized alpha preserves translucent smoke while keeping crisp pixels.
	float stepped_smoke = floor(clamp(smoke, 0.0, 1.0) * 5.0 + 0.5) / 5.0;
	stepped_smoke *= step(0.001, glow_width);
	// Blend both RGB and alpha from the inner color to the outer tint.
	float tint_amount = smoothstep(core_radius, core_radius + max(glow_width * 1.5, 0.001), distance_from_center);
	vec4 smoke_color = mix(inner_smoke_color, vec4(smoke_tint, 1.0), tint_amount);
	float alpha = max(core, stepped_smoke * glow_opacity * smoke_color.a);
	vec3 color = mix(smoke_color.rgb, vec3(1.0), core);
	COLOR = vec4(color, alpha) * COLOR;
}
