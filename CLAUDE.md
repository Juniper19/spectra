# Spectra — Godot Project Context

## Game Overview
2D color-switching platformer. The core mechanic: the player can only land on platforms that match their current color. Hold right-click to open a radial color wheel and switch colors. Built in Godot 4.7, GDScript only.

## Technical Setup
- **Renderer:** Compatibility (OpenGL3) — NOT Forward+
- **Platform:** Windows ARM64 (Surface Pro), crashes frequently under load
- **Resolution:** 1280x720 base

## Scene Structure
- `Level2` — main scene
  - `BG2` (CanvasLayer, layer = -1) — background layer
    - `ColorRect` — nebula shader (ShaderMaterial)
    - `Stars` (Node2D) — animated star field script
  - `BG` — static background node
  - `PlatformsRED/BLUE/GREEN/WHITE` — TileMapLayer nodes, one per color
  - `DeathPitLayer` — TileMapLayer, collision layer 16
  - `UI` (CanvasLayer)
    - `ColorSelector` — radial color wheel, shown on right-click
  - `MyPlayer` (CharacterBody2D)
    - `CollisionShape2D`
    - `Trail` (Node2D) — player trail effect script
    - `PlayerArt` (AnimatedSprite2D) — has outline ShaderMaterial
    - `Camera2D` — follows player, has smoothing
    - `FlowVisualizer/Vignette` — vignette ShaderMaterial driven by flow meter
  - `GlowShader` (CanvasLayer, layer = 10) — fullscreen bloom/chromatic aberration overlay
    - `ColorRect` — bloom ShaderMaterial, mouse_filter = Ignore
  - `ChromaticAbberation` — additional post-process node

## Key Systems

### Color System
- `total_colors`: [RED, GREEN, BLUE, YELLOW]
- `unlocked_colors`: array of indices into total_colors
- Player collision masks update on color change (layers 1-5, 16)
- Active platform: full color, no shader
- Inactive platforms: TileShader.gdshader (outline only)
- Color persists across scenes via root meta `unlocked_colors`

### Flow Meter
- Builds while player moves horizontally on the ground
- Decays when idle or pushing into a wall
- Increases movement speed up to 70% bonus
- Drives vignette intensity and color via shader parameters
- Has a start delay (2s) and re-delay after hitting 0

### Player Movement
- Coyote time, jump buffer, variable jump height
- Apex gravity modifier (floatier at peak)
- Direction-change momentum preservation
- Color swap: squash/stretch tween + push_out_of_tiles() to prevent clipping

## Current Performance Concerns
- `Stars` Node2D calls `queue_redraw()` every `_process` frame with nested loops (3x3 tiles × 96 stars × multiple draw calls each) — suspected RAM/GPU bottleneck
- Bloom shader uses a 9x9 gaussian blur loop (`-4 to 4` in both axes = 81 samples) — heavy for integrated GPU
- Game crashes frequently on Surface Pro ARM64, suspected cause is GPU/RAM overload from the above

## Shaders in Use
1. **Bloom/glow** (`GlowShader/ColorRect`) — fullscreen bloom + chromatic aberration + vignette
2. **Nebula** (`BG2/ColorRect`) — animated noise-based color wash background
3. **TileShader** (`res://Color Management/TileShader.gdshader`) — outline-only effect for inactive platforms
4. **Player outline** (`PlayerArt`) — colored outline matching current color
5. **Vignette** (`FlowVisualizer/Vignette`) — flow meter visualization, color matches player color

## Effects In Progress
- ✅ Player trail (Trail node, Node2D with _draw)
- ⬜ Color swap particle burst
- ⬜ Landing impact shockwave
- ⬜ Platform pulse (active platform breathes)
- ⬜ Platform wobble (vertex shader on white platforms)

## Visual Direction
Dark space aesthetic. References: bokeh lights, bioluminescent crowds, chromatic light bursts, artistic spike stars. "Seriously unserious" brand — deadpan, not cute. Shader overlay does heavy lifting so pixel art doesn't need to be complex yet.

## Files of Note
- `res://Color Management/TileShader.gdshader` — inactive platform outline shader
- Player script — `MyPlayer` node, handles movement, color switching, flow meter, collision masks
- Trail script — child of MyPlayer, Node2D with _draw based circle trail
- Stars script — child of BG2, grid-based tiling star field with soft glow and spike stars
