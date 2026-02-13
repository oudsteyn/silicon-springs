4km Terrain Pipeline (Godot 4)

Components
- `procedural_terrain_generator.gd`: layered fractal noise + island falloff.
- `hydraulic_erosion.gd`: simplified droplet-based erosion pass.
- `terrain_lod_manager.gd`: clipmap-style ring planning and chunk visibility.
- `terrain_noise_profile.gd`: tunable generation parameters.
- `res://src/graphics/shaders/terrain_triplanar_aaa.gdshader`: triplanar, slope blend, AO+normal integration.

Recommended runtime flow
1. Generate base heightmap at target resolution (e.g. 4096 x 4096).
2. Run 50k-200k erosion droplets offline or during loading.
3. Build near/far terrain clipmap meshes from the same height data.
4. Scatter micro detail (grass/rocks) using MultiMesh by height+slope masks.
5. Enable volumetric fog + subtle DoF in WorldEnvironment for distance integration.

Default generation profile
- Mountains: Simplex FBM, freq `0.00085`, oct `6`, lac `2.1`, gain `0.48`, weight `0.65`.
- Hills: Perlin FBM, freq `0.0028`, oct `5`, lac `2.0`, gain `0.5`, weight `0.28`.
- Plains: Perlin FBM, freq `0.009`, oct `3`, lac `2.0`, gain `0.55`, weight `0.07`.
- Falloff: start `0.62`, range `0.45`, power `2.4`.

LOD ring defaults
- Ring 0: radius `256m`, `1m/vertex`, collision on.
- Ring 1: radius `512m`, `2m/vertex`, collision on.
- Ring 2: radius `1024m`, `4m/vertex`, collision off.
- Ring 3: radius `2048m`, `8m/vertex`, collision off.
