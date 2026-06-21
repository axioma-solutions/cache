shader_type spatial;

   uniform sampler2D grass_texture : repeat_enable, filter_linear_mipmap;
   uniform float tile_scale : hint_range(1.0, 500.0) = 253.6;
   uniform float voronoi_scale : hint_range(0.1, 500.0) = 1.12;

   vec2 random2(vec2 p) {
       return fract(sin(vec2(
           dot(p, vec2(127.1, 311.7)),
           dot(p, vec2(269.5, 183.3))
       )) * 43758.5453);
   }

   // Returns the cell ID of the nearest voronoi point
   vec2 voronoi_cell(vec2 uv) {
       vec2 i = floor(uv);
       vec2 f = fract(uv);

       float min_dist = 1.0;
       vec2 closest_cell = i;

       for (int y = -1; y <= 1; y++) {
           for (int x = -1; x <= 1; x++) {
               vec2 neighbor = vec2(float(x), float(y));
               vec2 point = random2(i + neighbor);
               vec2 diff = neighbor + point - f;
               float dist = dot(diff, diff);
               if (dist < min_dist) {
                   min_dist = dist;
                   closest_cell = i + neighbor;
               }
           }
       }
       return closest_cell;
   }

   void fragment() {
       // Get voronoi cell for this fragment
       vec2 cell = voronoi_cell(UV * voronoi_scale);

       // Random rotation per cell (snapped to 90 degrees)
       float rand = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
       float angle = rand * 6.28318;

       // Tile the UV and rotate locally
       vec2 tiled_uv = fract(UV * tile_scale);
       vec2 centered = tiled_uv - 0.5;
       float c = cos(angle);
       float s = sin(angle);
       vec2 rotated = vec2(c * centered.x - s * centered.y, s * centered.x + c * centered.y) + 0.5;

       ALBEDO = texture(grass_texture, rotated).rgb;
       ROUGHNESS = 1.0;
   }