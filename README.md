# Cache

Game project by Axioma Solutions.

## Setup

### Prerequisites

1. **Godot 4.5+**
   - Download from https://godotengine.org/

2. **Git LFS** (required for 3D models and textures)
   ```bash
   brew install git-lfs
   git lfs install
   ```

3. **Blender** (optional, for 3D modeling)
   - Download from https://www.blender.org/

### Clone the repository

```bash
git clone https://github.com/axioma-solutions/cache.git
cd cache
```

If you already cloned without Git LFS, run:
```bash
git lfs pull
```

### Open in Godot

1. Open Godot
2. Click "Import"
3. Navigate to the `cache` folder
4. Select `project.godot`
5. Click "Import & Edit"

## Project Structure

```
cache/
├── scenes/
│   ├── main.tscn          # Main game scene
│   ├── player/            # Player character
│   ├── levels/            # Level scenes
│   └── props/             # Props and objects
├── scripts/               # GDScript files
├── blender_source/        # Blender .blend files
├── models/                # Exported 3D models (.glb)
└── textures/              # Texture images
```

## Development Workflow

- **projet-jaune** - Character movement and gameplay code
- **projet-noire** - 3D models, assets, and level design
- **master** - Stable, working version

Merge to master when features are complete.

## Controls

- **WASD** - Move
- **Space** - Jump
- **Shift** - Sprint
- **Mouse** - Look around
- **ESC** - Release mouse
