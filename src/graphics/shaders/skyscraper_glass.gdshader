shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D base_color_tex : source_color, repeat_enable;
uniform sampler2D normal_tex : hint_normal, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, repeat_enable; // R=AO, G=Roughness, B=Metallic
uniform sampler2D emission_tex : source_color, repeat_enable;
uniform sampler2D interior_tex : source_color, repeat_enable;

uniform float glass_reflectance : hint_range(0.0, 1.0) = 0.92;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.08;
uniform float parallax_strength : hint_range(0.0, 0.2) = 0.05;
uniform vec2 interior_tiling = vec2(6.0, 10.0);

uniform float city_time_norm : hint_range(0.0, 1.0) = 0.5;
uniform float night_emission_boost : hint_range(0.0, 8.0) = 2.5;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float night_factor(float t) {
	float evening = smoothstep(0.68, 0.78, t);
	float morning = 1.0 - smoothstep(0.18, 0.28, t);
	return max(evening, morning);
}

void fragment() {
	vec2 uv = UV;
	vec3 albedo = texture(base_color_tex, uv).rgb;
	vec3 orm = texture(orm_tex, uv).rgb;
	float ao = orm.r;
	float rough = max(base_roughness, orm.g * 0.6);
	float metal = max(orm.b, glass_reflectance);

	vec3 n = texture(normal_tex, uv).xyz * 2.0 - 1.0;

	vec2 cell_uv = uv * interior_tiling;
	vec2 cell_id = floor(cell_uv);
	vec2 local_uv = fract(cell_uv);

	vec2 view_shift = normalize(VIEW.xy) * parallax_strength;
	vec2 interior_uv = fract(local_uv + view_shift);
	vec3 interior_col = texture(interior_tex, interior_uv).rgb;

	float rnd = hash12(cell_id);
	float is_lit = step(0.62, rnd + night_factor(city_time_norm) * 0.55);

	vec4 emit_sample = texture(emission_tex, uv);
	vec3 emission = emit_sample.rgb * emit_sample.a * is_lit * night_factor(city_time_norm) * night_emission_boost;

	ALBEDO = mix(albedo, interior_col, 0.18);
	NORMAL_MAP = n * 0.5 + 0.5;
	ROUGHNESS = rough;
	METALLIC = metal;
	AO = ao;
	EMISSION = emission;
	SPECULAR = 1.0;
}
