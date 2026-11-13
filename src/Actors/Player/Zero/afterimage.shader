shader_type canvas_item;

// Flat silhouette of the sprite: keeps only the alpha, so the node's modulate
// decides the ghost's color and opacity.
void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a);
}
