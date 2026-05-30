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
debug_mode := Debug.Off
current_mat := Material.Sand
select_explosive := false
spawn_radius := 4
t_scale: f64 = 1
// constant
Chunk_Size :: 16
Width_Chunk :: (480 + 15) / Chunk_Size
Height_Chunk :: (270 + 15) / Chunk_Size
Chunk_Idle_Thresh :: 6
Dt: f64 : 1.0 / 60.0
Width :: 480
Height :: 270
Gravity: f32 : 50
Scale :: 4
// global material constant
Max_Step_Y :: 8
// sand constant
X_Threshold :: 0.25
Max_Vx :: 2.5
Max_Vy :: 8.0

Resting_Damping :: 0.5
Y_Damp_On_Hit :: 0.4

Diagonal_X_Transfer :: 0.6
Diagonal_Y_Transfer :: 0.5
Horizontal_X_Transfer :: 0.3
Horizontal_Y_Transfer :: 0.2

Impact_To_Side :: 0.75
Neighbor_Transfer :: 0.3

Sleep_Epsilon :: 0.1
// water constant
Max_Step_X :: 4
Impact_To_Side_Liquid :: 0.3
