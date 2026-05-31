package simulation

import "core:encoding/json"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"
Debug :: enum {
	Off,
	Velocity_Y,
	Velocity_X,
	Chunk,
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
	Hot_Reload,
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
	.Hot_Reload          = {0, .R, {.Ctrl}},
}
// runtime config
T_Scales: []f64 : []f64{0.01, 0.05, 0.1, 0.5, 0.75, 1}
// constant
Fallback_Conf :: World_Config{Material_Config{30.0, 1.0, 1.0, 8, 4, 0.8, 0.5, 0.3, 4.5, 0.1}}
Config_Path :: "./config/world_config.json"
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

load_world_config :: proc(path: string) -> World_Config {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		panic(fmt.tprintfln("Failed to load file: %v", err))
	}
	defer delete(data)
	config: World_Config
	unmarshal_err := json.unmarshal(data, &config)
	if unmarshal_err != nil {
		fmt.eprintfln("Failed to parse config file, loaded fallback config")
		return Fallback_Conf
	}
	return config
}
