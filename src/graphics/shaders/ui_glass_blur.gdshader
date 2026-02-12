shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_px = 3.0;
uniform vec4 tint : source_color = vec4(0.08, 0.10, 0.13, 0.62);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = blur_px / vec2(textureSize(screen_tex, 0));
	vec4 c = vec4(0.0);
	c += texture(screen_tex, uv + vec2(-px.x, 0.0));
	c += texture(screen_tex, uv + vec2(px.x, 0.0));
	c += texture(screen_tex, uv + vec2(0.0, -px.y));
	c += texture(screen_tex, uv + vec2(0.0, px.y));
	c += texture(screen_tex, uv);
	c /= 5.0;

	COLOR = mix(c, tint, tint.a);
}
