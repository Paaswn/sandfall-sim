package simulation

import rl "vendor:raylib"
Debug :: enum {
	Off,
	Velocity_Y,
	Velocity_X,
	Chunk,
}
Action :: enum {
	Debug_Off,
	Debug_Velocity_Y,
	Debug_Velocity_X,
	Debug_Chunk,
	Select_Sand,
	Select_Empty,
	Select_Cement,
	Select_Water,
	Increase_Tick,
	Decrease_Tick,
	Increase_Brush_Size,
	Decrease_Brush_Size,
	Make_Spawn_Point,
}
Modifier_Key :: enum {
	None,
	Ctrl,
	Shift,
	Alt,
}
Material_Config :: struct {
    down_acc : f32,
    slide_thresh : f32,
    side_thresh : f32,
    max_vy: f32,
    max_vx: f32,
    friction: f32,
    damp: f32,
    impact_to_side: f32,
}
Modifiers :: bit_set[Modifier_Key]
Input :: struct {
	mouse_wheel: int,
	trigger:     rl.KeyboardKey,
	modifer:     Modifiers,
}
Key_Binds :: [Action]Input {
	.Debug_Off           = {0, .ONE, {.Ctrl}},
	.Debug_Velocity_Y    = {0, .TWO, {.Ctrl}},
	.Debug_Velocity_X    = {0, .THREE, {.Ctrl}},
	.Debug_Chunk         = {0, .FOUR, {.Ctrl}},
	.Select_Sand         = {0, .TWO, {.None}},
	.Select_Empty        = {0, .ONE, {.None}},
	.Select_Cement       = {0, .THREE, {.None}},
	.Increase_Tick       = {1, .KEY_NULL, {.Shift}},
	.Decrease_Tick       = {-1, .KEY_NULL, {.Shift}},
	.Increase_Brush_Size = {1, .KEY_NULL, {.Ctrl}},
	.Decrease_Brush_Size = {-1, .KEY_NULL, {.Ctrl}},
	.Select_Water        = {0, .FOUR, {.None}},
	.Make_Spawn_Point    = {0, .F, {.None}},
}
// runtime config
T_Scales :[]f64 : []f64{0.01, 0.05, 0.1, 0.5, 0.75, 1}
// constant
Chunk_Size :: 16
Width_Chunk :: (480 + 15) / Chunk_Size
Height_Chunk :: (270 + 15) / Chunk_Size
Max_Chunk_Idx :: Width_Chunk * Height_Chunk - 1
Chunk_Idle_Thresh :: 6
Dt: f64 : 1.0 / 60.0
Width :: 480
Height :: 270
Gravity: f32 : 30
Scale :: 4
Brush_Size :: 4
T_Scale :: 5
Start_Mat :: Material.Sand
// global material constant
