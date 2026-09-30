shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float grayscale_amount : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.85, 0.2, 0.2, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(c.rgb, vec3(gray), grayscale_amount);
	vec3 tinted = mix(desaturated, desaturated * tint_color.rgb * 1.4, tint_amount);
	
	vec2 uv = SCREEN_UV * (1.0 - SCREEN_UV.xy);
	float vig = uv.x * uv.y * 15.0;
	vig = clamp(pow(vig, 0.35), 0.0, 1.0);
	vec3 final_color = mix(vec3(0.0), tinted, mix(1.0, vig, vignette_amount));
	
	COLOR = vec4(final_color, 1.0);
}
