shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float uv_scale = 0.08;
uniform float normal_strength = 1.0;
uniform float roughness_mult = 1.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec4 triplanar_sample(sampler2D tex, vec3 p, vec3 n) {
	vec3 bn = abs(n);
	bn = max(bn, vec3(0.0001));
	bn /= (bn.x + bn.y + bn.z);

	vec2 uvx = p.zy * uv_scale;
	vec2 uvy = p.xz * uv_scale;
	vec2 uvz = p.xy * uv_scale;

	vec4 sx = texture(tex, uvx);
	vec4 sy = texture(tex, uvy);
	vec4 sz = texture(tex, uvz);

	return sx * bn.x + sy * bn.y + sz * bn.z;
}

void fragment() {
	vec3 nrm = normalize(wnorm);
	vec4 alb = triplanar_sample(albedo_tex, wpos, nrm);
	vec3 ntex = triplanar_sample(normal_tex, wpos, nrm).xyz * 2.0 - 1.0;
	float rough = triplanar_sample(roughness_tex, wpos, nrm).r;

	ALBEDO = alb.rgb;
	NORMAL = normalize(vec3(ntex.xy * normal_strength, ntex.z));
	ROUGHNESS = clamp(rough * roughness_mult, 0.04, 1.0);
	METALLIC = 0.0;
}
