## 📌 Architecture Refactor Roadmap

### 📜 Current State (v1.0 - 2D Fake Z-Depth)
- **Rendering:** Multi-layered `TileMapLayer` with dynamic `z_index` and `y_sort_origin` shifts.
- **Data Model:** 2D Heightmap array (`world_data[Vector2i] = { "z": height }`).
- **Features:** Noise terrain generation, chunk management, tile interaction (`mine_ground` / `build_ground`).
- **Limitation:** Fragile depth sorting, potential overdraw, unable to support complex 3D structures (caves, overhangs).

---

### 🚀 Target State (v2.0 - Native 3D Orthographic)
Transition from 2D software layering to native 3D spatial coordinate system (inspired by Unity's underlying $X, Y, Z$ mesh architecture in *ISO-CORE* by JohnBrx).

- [ ] **Core Scene Setup**
  - Migrate world root from `Node2D` to `Node3D`.
  - Replace `Camera2D` with `Camera3D` in **Orthographic** projection mode ($X = -30^\circ, Y = 45^\circ$).
  
- [ ] **Rendering Engine**
  - Replace `TileMapLayer` array with `Sprite3D` or `MultiMeshInstance3D` (Voxel rendering).
  - Offload depth sorting entirely to hardware GPU Z-Buffer.

- [ ] **Data & Logic Adaptation**
  - Convert `world_data` from 2D Heightmap to 3D Voxel Dictionary (`world_data[Vector3i] = block_id`).
  - Retain `WorldGenerator` noise logic, adapting outputs to 3D voxel coordinates.
  - Port `mine_ground` / `build_ground` logic to directly manipulate 3D grid states.
