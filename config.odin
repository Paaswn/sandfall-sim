package main

import rl "vendor:raylib"
Debug :: enum {
	Off,
	Velocity_Y,
	Velocity_X,
	Active_Cell,
}
Action :: enum {
	Debug_Off,
	Debug_Velocity_Y,
	Debug_Velocity_X,
	Debug_Active_Cell,
	Select_Sand,
	Select_Empty,
	Select_Cement
}
Modifier_Key :: enum {
	None,
	Ctrl,
	Shift,
	Alt,
}
Modifiers :: bit_set[Modifier_Key]
Input :: struct {
	trigger: rl.KeyboardKey,
	modifer: Modifiers,
}
KEY_BINDS :: [Action]Input {
	.Debug_Off         = {.ONE, {.Ctrl}},
	.Debug_Velocity_Y  = {.TWO, {.Ctrl}},
	.Debug_Velocity_X  = {.THREE, {.Ctrl}},
	.Debug_Active_Cell = {.FOUR, {.Ctrl}},
	.Select_Sand       = {.TWO, {.None}},
	.Select_Empty      = {.ONE, {.None}},
	.Select_Cement     = {.THREE, {.None}},
}
// runtime config
debug_mode := Debug.Off
current_mat := Material.Sand
select_explosive := false
spawn_radius := 4
// constant
DT: f64 : 1.0 / 60.0
WIDTH :: 480
HEIGHT :: 270
GRAVITY: f32 : 50
SCALE :: 4
// sand constant
MAX_STEP_Y :: 8

X_THRESHOLD :: 0.25
MAX_VX :: 2.5
MAX_VY :: 8.0

RESTING_DAMPING :: 0.5
Y_DAMP_ON_HIT :: 0.5

DIAGONAL_X_TRANSFER :: 0.6
DIAGONAL_Y_TRANSFER :: 0.5
HORIZONTAL_X_TRANSFER :: 0.2
HORIZONTAL_Y_TRANSFER :: 0.2

IMPACT_TO_SIDE :: 0.9
NEIGHBOR_TRANSFER :: 0.3

SLEEP_EPSILON :: 0.1
