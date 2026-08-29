# 2D Platformer Game - Godot 4

A 2D platformer game built in Godot 4.7.1 following the reference tutorial series *How to Make a 2D Platformer in Godot* by Coding With Russ.

## 🎥 Video Demo

**▶️ [Tonton Video Demo Gameplay](./Recording.mp4)**

Video di atas merupakan rekaman gameplay dan pengujian game. Klik link tersebut untuk membuka video `Recording.mp4` yang tersedia di repository.

## Features

- **Character Controller**: Smooth physics movement, jumping (`-550.0 px/s`), gravity, dynamic sprite direction flipping, and state-driven animations (`idle`, `run`, `jump`, `fall`).
- **3-Level Progression**:
  - `Level 1`: Introduction to platforming terrain and stepping stones.
  - `Level 2`: Island platforms bridging a central pit.
  - `Level 3`: Vertical platform climb to the summit.
- **Smooth Scene Transitions**: Full-screen fade-to-black and fade-in transition system between levels.
- **Continuous Background Music**: Autoload audio manager that streams background music persistently across level changes without resetting.
- **Sound Effects**: Audio cues for jumping (`jump.wav`) and goal/exit entry (`power_up.wav`).
- **Collision & TileMap**: Godot 4 `TileMapLayer` setup with full physics collision polygons on solid terrain tiles.

## Controls

| Action | Primary Key | Secondary Key |
| :--- | :--- | :--- |
| **Move Left** | `A` | `Left Arrow` |
| **Move Right** | `D` | `Right Arrow` |
| **Jump** | `Space` / `W` | `Up Arrow` |

## Project Structure

- `player.tscn` / `player.gd`: Player CharacterBody2D scene and controller script.
- `exit.tscn` / `exit.gd`: Level exit goal trigger Area2D.
- `level_1.tscn`, `level_2.tscn`, `level_3.tscn`: Playable level stages.
- `audio_manager.gd`: Autoload singleton for continuous background music.
- `scene_transition.tscn` / `scene_transition.gd`: Autoload CanvasLayer singleton for fade transitions.
- `project.godot`: Godot 4 engine configuration.

## Kendala dan Solusi

Selama proses pengerjaan proyek, tidak terdapat kendala besar yang menghambat proses pengembangan game.

Proses pembuatan dan implementasi fitur dapat dilakukan dengan baik menggunakan Godot Engine 4.7.1. Setelah seluruh fitur selesai dibuat, proyek juga dilakukan pengujian untuk memastikan player movement, jumping, animation, collision, audio, transisi level, dan pergantian antar level berjalan dengan baik.

Karena tidak terdapat kendala yang signifikan, tidak ada proses troubleshooting khusus yang diperlukan selain melakukan pengecekan dan pengujian pada setiap fitur yang telah dibuat.

## Credits

- Game development: PlatfrommerJose
- Engine: Godot 4.7.1
- Reference tutorial: Coding With Russ
