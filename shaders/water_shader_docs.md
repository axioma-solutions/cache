# Water Shader — Physics & Implementation

## Overview

This shader simulates a water surface without modifying geometry. All visual effects (waves, reflections, refraction) are computed per-pixel in the fragment shader using procedural noise and physical approximations.

---

## Layer 1: World Position (Vertex Shader)

**Physics:** We need to know where each point on the surface is in 3D space, independent of mesh UVs.

**Implementation:** The vertex shader transforms each vertex from local model space to world space using the Model matrix (`MODEL_MATRIX`). This position is passed to the fragment shader via a `varying` variable, which the GPU interpolates across each triangle.

```
world_pos = MODEL_MATRIX * VERTEX
```

This is equivalent to Blender's "Object" texture coordinate output.

---

## Layer 2: Value Noise

**Physics:** Natural phenomena like water don't have perfectly periodic motion. We need a smooth pseudo-random function that produces organic-looking variation.

**Algorithm:** Value noise divides 2D space into a grid. Each grid corner gets a deterministic pseudo-random value via a hash function. For any point within a cell, we interpolate between the four surrounding corner values using a smoothstep curve.

**Hash function:** `fract(sin(dot(p, constants)) * 43758.5453)` — exploits the chaotic behavior of `sin()` at large values. The `fract()` extracts only the fractional part, producing a uniform 0–1 distribution.

**Interpolation curve:** `f = f * f * (3.0 - 2.0 * f)` — Hermite interpolation (smoothstep). Produces C1 continuity: the noise is smooth with no visible grid edges.

**Reference:** https://en.wikipedia.org/wiki/Value_noise

---

## Layer 3: Fractal Brownian Motion (fBm)

**Physics:** Real water surfaces have detail at multiple scales simultaneously — large ocean swells, medium waves, small ripples, tiny surface tension effects. This is characteristic of fractal self-similarity in fluid dynamics.

**Algorithm:** Layer the value noise function multiple times (6 octaves). Each successive layer ("octave"):
- Doubles the frequency (smaller features)
- Halves the amplitude (less influence)
- Rotates the coordinate space by ~37° via a rotation matrix (prevents axis-aligned artifacts)
- Animates at a different speed (temporal variation)

The sum produces a signal with a 1/f power spectrum — matching real-world turbulence (Kolmogorov spectrum).

**LOD optimization:** Distant pixels use fewer octaves (controlled by `detail` parameter). High-frequency octaves are invisible at distance and would cause aliasing/shimmer.

**Reference:** https://en.wikipedia.org/wiki/Fractional_Brownian_motion

---

## Layer 4: Wave Displacement

**Physics:** The water surface deforms over time. Each point moves in a 2D pattern determined by the sum of many wave components traveling in different directions.

**Implementation:** Two independent fBm evaluations (with different seed offsets) produce a 2D displacement vector per pixel. This vector represents how much the surface "moves" at that point.

- `wave_scale` controls spatial frequency (wave size)
- `wave_speed` controls temporal frequency (animation speed)
- `wave_strength` controls displacement amplitude

The two fBm calls use different spatial offsets (`+vec2(5.2, 1.3)`) and time multipliers (`*0.7`) so they never correlate, producing realistic 2D motion.

---

## Layer 5: Surface Normals (Finite Differences)

**Physics:** Light reflects off a surface based on its orientation (normal vector). A wavy surface has a different normal at every point, creating the characteristic shimmering reflections of water.

**Algorithm:** We compute the normal numerically using finite differences. Sample the wave displacement at:
- The current point: `h(x, z)`
- A point slightly to the right: `h(x + ε, z)`
- A point slightly forward: `h(x, z + ε)`

The slopes are:
```
dx = (h(x+ε, z) - h(x, z)) / ε
dz = (h(x, z+ε) - h(x, z)) / ε
```

The normal is `normalize(-dx, 1.0, -dz)` — perpendicular to the surface at that point.

This is then transformed to view space for Godot's lighting system.

**Reference:** https://en.wikipedia.org/wiki/Finite_difference

---

## Layer 6: Fresnel Effect

**Physics:** When you look at water at a shallow (grazing) angle, it appears more reflective and opaque. When you look straight down, you can see through it to the bottom. This is the Fresnel effect, caused by the physics of electromagnetic wave transmission at material boundaries.

**Algorithm:** Schlick's approximation:
```
fresnel = (1 - dot(normal, view_direction))³
```

At grazing angles, `dot(N, V)` approaches 0 → fresnel approaches 1 (fully reflective). At steep angles, `dot(N, V)` approaches 1 → fresnel approaches 0 (transparent).

The exponent (3) controls how sharp the transition is. Real water uses ~5, but 3 looks good for stylized rendering.

**Reference:** https://en.wikipedia.org/wiki/Schlick%27s_approximation

---

## Layer 7: Refraction

**Physics:** Light bends (refracts) when passing from air into water (Snell's law). This causes objects below the surface to appear distorted — straight lines become wavy, positions shift.

**Algorithm:** We sample the screen texture (everything already rendered behind the water) at a UV offset determined by the surface normal:
```
refracted_uv = screen_uv + normal.xz * refraction_strength
```

Where the surface tilts more (steeper normal), the view bends more. This is a screen-space approximation — not physically accurate ray-bending, but visually convincing.

The `refraction_strength` parameter controls how much distortion occurs.

**Reference:** https://en.wikipedia.org/wiki/Refraction

---

## Layer 8: Color Composition

**Physics:** Water absorbs light, shifting color toward blue/green with depth. The surface also has its own color from scattered light.

**Implementation:** 
1. A base pattern (`sin * cos` distorted by wave offset) creates spatial color variation between `shallow_color` and `deep_color`
2. The refracted background (what's below) is blended with the water color
3. The blend factor is controlled by fresnel: at steep viewing angles you see more of the bottom (refracted), at shallow angles you see more water color and reflection

```
final = mix(refracted_background, water_color, opacity)
opacity = mix(base_alpha, 1.0, fresnel)
```

---

## Layer 9: Specular Reflection

**Physics:** Smooth water has mirror-like specular highlights from light sources (sun glint). The roughness of the surface determines how tight or spread out these highlights are.

**Implementation:** Godot's built-in PBR lighting handles this using the normal we provide:
- `ROUGHNESS = 0.05` — very smooth, tight specular highlights
- `SPECULAR = 0.8` — high reflectance for bright sun reflections
- `METALLIC = 0.0` — water is a dielectric (non-metal)

The wavy normals cause the specular highlight to break up into many small bright spots, creating the "sun bridge" effect on water.

---

## Signal Flow Diagram

```
world_pos.xz
    │
    ├─→ fbm (6 octaves, animated) ──→ wave_offset (vec2)
    │                                      │
    │                                      ├─→ distort color pattern
    │                                      │
    │                                      └─→ finite differences ──→ surface normal
    │                                                                      │
    │                                                                      ├─→ view-space NORMAL (specular)
    │                                                                      ├─→ fresnel (blend factor)
    │                                                                      └─→ refraction UV offset
    │
    └─→ camera distance ──→ LOD (octave count reduction)

screen_texture + refraction offset ──→ refracted background
water_color + fresnel + refracted background ──→ final ALBEDO
```

---

## Parameters

| Parameter | Effect | Typical Range |
|-----------|--------|---------------|
| `shallow_color` | Water color in shallow/lit areas | Teal/cyan |
| `deep_color` | Water color in deep/dark areas | Dark blue |
| `wave_speed` | Animation speed | 0.5 – 2.0 |
| `wave_scale` | Wave spatial frequency (higher = smaller waves) | 5 – 20 |
| `wave_strength` | Wave amplitude | 0.01 – 0.05 |
| `refraction_strength` | How much the view bends | 0.01 – 0.05 |
| `specular_strength` | Sun reflection intensity | 0.5 – 1.5 |
| `alpha` | Base opacity | 0.5 – 0.8 |

---

## References

- Value noise: https://en.wikipedia.org/wiki/Value_noise
- Fractional Brownian motion: https://en.wikipedia.org/wiki/Fractional_Brownian_motion
- Finite differences: https://en.wikipedia.org/wiki/Finite_difference
- Fresnel equations: https://en.wikipedia.org/wiki/Fresnel_equations
- Schlick's approximation: https://en.wikipedia.org/wiki/Schlick%27s_approximation
- Refraction (Snell's law): https://en.wikipedia.org/wiki/Snell%27s_law
- The Book of Shaders (noise, fbm): https://thebookofshaders.com/
- Inigo Quilez (hash functions): https://iquilezles.org/articles/sfrand/
