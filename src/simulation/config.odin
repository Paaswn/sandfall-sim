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
	mouse_wheel: Wheel_State,
	trigger:     rl.KeyboardKey,
	modifer:     Modifiers,
}

Wheel_State :: enum {
	Up,
	None,
	Down,
}

Action :: enum {
	Debug_Off,
	Debug_Velocity_Y,
	Debug_Velocity_X,
	Debug_Chunk,
	Select_Empty,
	Select_Sand,
	Select_Cement,
	Select_Dirt,
	Select_Water,
	Increase_Tick,
	Decrease_Tick,
	Increase_Brush_Size,
	Decrease_Brush_Size,
	Make_Spawn_Point,
	Hot_Reload,
}
Key_Binds :: [Action]Input {
	.Debug_Off           = {.None, .ONE, {.Ctrl}},
	.Debug_Velocity_Y    = {.None, .TWO, {.Ctrl}},
	.Debug_Velocity_X    = {.None, .THREE, {.Ctrl}},
	.Debug_Chunk         = {.None, .FOUR, {.Ctrl}},
	.Select_Empty        = {.None, .ONE, {.None}},
	.Select_Sand         = {.None, .TWO, {.None}},
	.Select_Cement       = {.None, .THREE, {.None}},
	.Select_Water        = {.None, .FOUR, {.None}},
	.Select_Dirt         = {.None, .FIVE, {.None}},
	.Increase_Tick       = {.Up, .KEY_NULL, {.Shift}},
	.Decrease_Tick       = {.Down, .KEY_NULL, {.Shift}},
	.Increase_Brush_Size = {.Up, .KEY_NULL, {.Ctrl}},
	.Decrease_Brush_Size = {.Down, .KEY_NULL, {.Ctrl}},
	.Make_Spawn_Point    = {.None, .F, {.None}},
	.Hot_Reload          = {.None, .R, {.Ctrl}},
}
// runtime config
T_Scales: []f64 : []f64{0.01, 0.05, 0.1, 0.5, 0.75, 1}
// constant
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
Fallback_Conf: [Material]Material_Config = {
	.Empty  = Powder_Config{},
	.Sand   = Powder_Config{},
	.Dirt   = Powder_Config{},
	.Water  = Powder_Config{},
	.Cement = Powder_Config{},
}
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
