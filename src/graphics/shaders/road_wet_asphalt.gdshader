shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, repeat_enable;
uniform sampler2D normal_tex : hint_normal, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, repeat_enable; // R=AO, G=Roughness, B=Metallic
uniform sampler2D detail_normal_tex : hint_normal, repeat_enable;
uniform sampler2D puddle_mask_tex : hint_default_white, repeat_enable;

uniform float uv_scale = 1.0;
uniform float detail_uv_scale = 10.0;
uniform float detail_normal_strength : hint_range(0.0, 1.0) = 0.35;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float wet_darken : hint_range(0.0, 1.0) = 0.30;
uniform float puddle_smoothness : hint_range(0.0, 1.0) = 0.85;

vec3 blend_detail_normal(vec3 n1, vec3 n2, float strength) {
	n2 = normalize(mix(vec3(0.0, 0.0, 1.0), n2, strength));
	return normalize(vec3(n1.xy + n2.xy, n1.z * n2.z));
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec2 duv = UV * detail_uv_scale;

	vec3 base_albedo = texture(albedo_tex, uv).rgb;
	vec3 orm = texture(orm_tex, uv).rgb;
	float ao = orm.r;
	float base_rough = orm.g;
	float metal = orm.b;

	vec3 n_base = texture(normal_tex, uv).xyz * 2.0 - 1.0;
	vec3 n_detail = texture(detail_normal_tex, duv).xyz * 2.0 - 1.0;
	vec3 n = blend_detail_normal(n_base, n_detail, detail_normal_strength);

	float crevice = pow(clamp(1.0 - base_rough, 0.0, 1.0), 1.4);
	float puddle_mask = texture(puddle_mask_tex, uv).r;
	float pooled = clamp(mix(crevice, puddle_mask, 0.5), 0.0, 1.0) * wetness;

	vec3 wet_albedo = base_albedo * (1.0 - wet_darken * (0.35 + 0.65 * pooled));
	float wet_rough = mix(base_rough, 0.03, pooled * puddle_smoothness);

	ALBEDO = wet_albedo;
	NORMAL_MAP = n * 0.5 + 0.5;
	ROUGHNESS = wet_rough;
	METALLIC = metal;
	AO = ao;
	SPECULAR = mix(0.5, 0.95, wetness);
}
