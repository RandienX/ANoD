shader_type canvas_item;

// The color we want to detect in the texture
instance uniform vec3 target_color : source_color = vec3(1.0, 0.0, 0.0);

// How close the colors need to be to match (0.0 to 1.0)
uniform float threshold : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	// Get the color from the texture
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Calculate the difference between the texture color and the target color
	float diff = distance(tex_color.rgb, target_color.rgb);
	
	// Define our output colors
	vec4 highlight_color = vec4(0.0, 1.0, 0.0, 0.4);
	vec4 transparent_color = vec4(0.0, 0.0, 0.0, 0.0);
	
	if (diff < threshold) {
		COLOR = highlight_color;
	} else {
		COLOR = transparent_color;
	}
}