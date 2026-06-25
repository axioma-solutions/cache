shader_type spatial;

// inputs

uniform sampler2D grass_texture : repeat_enable, filter_linear_mipmap;
uniform float tile_scale : hint_range(0.01, 500.0) = 1.0;
uniform float voronoi_scale : hint_range(0.00, 10.0) = 1.0;
varying vec3 world_pos; // varying is a variable that the vertex shader can write

// fragment shader (manipulates/uses world coordinates of vertices)
// in Godot, we don't need a separate file, just a separate function
// use VERTEX for each coordinate (object space)
// MODEL_MATRIX transforms to global space

void vertex() {
		// we don't actually do anything special here
       world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 get_cell() {
	return floor(world_pos.xz * voronoi_scale);
}

vec2 calculate_center(int i, int j) {
	return fract(sin(vec2(
       dot(vec2(float(i), float(j)), vec2(127.1, 311.7)),
       dot(vec2(float(i), float(j)), vec2(269.5, 183.3))
   )) * 43758.5453);
}

vec3 voronoi() {
	vec2 cell = get_cell();
	int x = int(cell.x);
	int y = int(cell.y);
	
	int min_i;
	int min_j;
	float min_dist = 9999.0;
	
	for (int i = x - 1; i <= x + 1; i++) {
		for (int j = y - 1; j <= y + 1; j++) {
			vec2 center = (vec2(float(i), float(j)) + calculate_center(i, j)) / voronoi_scale;
			float new_dist = distance(center, world_pos.xz);
			if (new_dist < min_dist) {
				min_dist = new_dist;
				min_i = i;
				min_j = j;
			}
		}
	}
	
	return vec3(
       fract(sin(dot(vec2(float(min_i), float(min_j)), vec2(127.1, 311.7))) * 43758.5453),
       fract(sin(dot(vec2(float(min_i), float(min_j)), vec2(269.5, 183.3))) * 43758.5453),
       fract(sin(dot(vec2(float(min_i), float(min_j)), vec2(419.2, 371.9))) * 43758.5453)
	);
}


void fragment() {
	vec3 vor = voronoi();
	float angle = vor.x * 6.28318;
	vec2 offset = vec2(vor.y, vor.z);

	vec2 tiled_uv = fract(UV * tile_scale + offset);
	vec2 centered = tiled_uv - 0.5;
	float c = cos(angle);
	float s = sin(angle);
	vec2 rotated = vec2(c * centered.x - s * centered.y, s * centered.x + c * centered.y) + 0.5;

	ALBEDO = texture(grass_texture, rotated).rgb;
}

// old stuff
//shader_type spatial;
//uniform sampler2D grass_texture : repeat_enable, filter_linear_mipmap;
//uniform float tile_scale : hint_range(1.0, 500.0) = 253.6;
//uniform float voronoi_scale : hint_range(0.1, 500.0) = 1.12;

//vec2 random2(vec2 p) {
//    return fract(sin(vec2(
//        dot(p, vec2(127.1, 311.7)),
//        dot(p, vec2(269.5, 183.3))
//    )) * 43758.5453);
//}

// Returns the cell ID of the nearest voronoi point
//vec2 voronoi_cell(vec2 uv) {
    //vec2 i = floor(uv);
    //vec2 f = fract(uv);
//
    //float min_dist = 1.0;
    //vec2 closest_cell = i;
//
    //for (int y = -1; y <= 1; y++) {
        //for (int x = -1; x <= 1; x++) {
            //vec2 neighbor = vec2(float(x), float(y));
            //vec2 point = random2(i + neighbor);
            //vec2 diff = neighbor + point - f;
            //float dist = dot(diff, diff);
            //if (dist < min_dist) {
                //min_dist = dist;
                //closest_cell = i + neighbor;
            //}
        //}
    //}
    //return closest_cell;
//}
//
//void fragment() {
    //// Get voronoi cell for this fragment
    //vec2 cell = voronoi_cell(UV * voronoi_scale);
//
    //// Random rotation per cell (snapped to 90 degrees)
    //float rand = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
    //float angle = rand * 6.28318;
//
    //// Tile the UV and rotate locally
    //vec2 tiled_uv = fract(UV * tile_scale);
    //vec2 centered = tiled_uv - 0.5;
    //float c = cos(angle);
    //float s = sin(angle);
    //vec2 rotated = vec2(c * centered.x - s * centered.y, s * centered.x + c * centered.y) + 0.5;
//
    //ALBEDO = texture(grass_texture, rotated).rgb;
    //ROUGHNESS = 1.0;
//}