shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D grass_albedo : source_color;
uniform sampler2D rock_albedo  : source_color;
uniform sampler2D sand_albedo  : source_color;

uniform sampler2D grass_normal : hint_normal;
uniform sampler2D rock_normal  : hint_normal;
uniform sampler2D sand_normal  : hint_normal;

uniform sampler2D grass_ao;
uniform sampler2D rock_ao;
uniform sampler2D sand_ao;

uniform float uv_scale = 0.06;
uniform float normal_scale = 1.0;

uniform float slope_rock_start = 0.45;
uniform float slope_rock_end = 0.72;

uniform float sea_level = 28.0;
uniform float beach_band = 8.0;

uniform float rough_grass = 0.78;
uniform float rough_rock = 0.92;
uniform float rough_sand = 0.66;

vec3 triplanar_weights(vec3 n) {
	vec3 an = abs(n);
	an = pow(an, vec3(6.0));
	return an / max(an.x + an.y + an.z, 1e-5);
}

vec4 sample_triplanar_albedo(sampler2D tex, vec3 wp, vec3 w) {
	vec2 uvx = wp.zy * uv_scale;
	vec2 uvy = wp.xz * uv_scale;
	vec2 uvz = wp.xy * uv_scale;
	return texture(tex, uvx) * w.x + texture(tex, uvy) * w.y + texture(tex, uvz) * w.z;
}

vec3 sample_triplanar_normal(sampler2D tex, vec3 wp, vec3 w) {
	vec2 uvx = wp.zy * uv_scale;
	vec2 uvy = wp.xz * uv_scale;
	vec2 uvz = wp.xy * uv_scale;

	vec3 nx = texture(tex, uvx).xyz * 2.0 - 1.0;
	vec3 ny = texture(tex, uvy).xyz * 2.0 - 1.0;
	vec3 nz = texture(tex, uvz).xyz * 2.0 - 1.0;

	nx = vec3(nx.z, nx.y, nx.x);
	ny = vec3(ny.x, ny.z, ny.y);
	nz = vec3(nz.x, nz.y, nz.z);

	return normalize(nx * w.x + ny * w.y + nz * w.z);
}

float sample_triplanar_ao(sampler2D tex, vec3 wp, vec3 w) {
	vec2 uvx = wp.zy * uv_scale;
	vec2 uvy = wp.xz * uv_scale;
	vec2 uvz = wp.xy * uv_scale;
	float ax = texture(tex, uvx).r;
	float ay = texture(tex, uvy).r;
	float az = texture(tex, uvz).r;
	return ax * w.x + ay * w.y + az * w.z;
}

void fragment() {
	vec3 wp = WORLD_POSITION;
	vec3 wn = normalize(NORMAL);
	vec3 tw = triplanar_weights(wn);

	float slope = 1.0 - abs(wn.y);
	float rock_w = smoothstep(slope_rock_start, slope_rock_end, slope);

	float shore = 1.0 - smoothstep(sea_level, sea_level + beach_band, wp.y);
	float sand_w = clamp(shore * (1.0 - rock_w), 0.0, 1.0);
	float grass_w = clamp(1.0 - rock_w - sand_w, 0.0, 1.0);

	vec4 grass_c = sample_triplanar_albedo(grass_albedo, wp, tw);
	vec4 rock_c  = sample_triplanar_albedo(rock_albedo, wp, tw);
	vec4 sand_c  = sample_triplanar_albedo(sand_albedo, wp, tw);

	ALBEDO = grass_c.rgb * grass_w + rock_c.rgb * rock_w + sand_c.rgb * sand_w;

	vec3 ng = sample_triplanar_normal(grass_normal, wp, tw);
	vec3 nr = sample_triplanar_normal(rock_normal, wp, tw);
	vec3 ns = sample_triplanar_normal(sand_normal, wp, tw);
	NORMAL_MAP = normalize(ng * grass_w + nr * rock_w + ns * sand_w);
	NORMAL_MAP_DEPTH = normal_scale;

	float aog = sample_triplanar_ao(grass_ao, wp, tw);
	float aor = sample_triplanar_ao(rock_ao, wp, tw);
	float aos = sample_triplanar_ao(sand_ao, wp, tw);
	AO = aog * grass_w + aor * rock_w + aos * sand_w;

	ROUGHNESS = rough_grass * grass_w + rough_rock * rock_w + rough_sand * sand_w;
	METALLIC = 0.0;
}
