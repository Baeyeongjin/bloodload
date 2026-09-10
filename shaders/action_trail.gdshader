shader_type canvas_item;
render_mode unshaded;

varying vec4 trail_tint;

void vertex() {
	trail_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, trail_tint.rgb, 0.82), tex.a * trail_tint.a);
}
