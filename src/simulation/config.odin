package simulation

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:reflect"
import rl "vendor:raylib"
Debug :: enum {
	Off,
	Velocity_Y,
	Velocity_X,
}
// runtime config
T_Scales: []f64 : []f64{0.01, 0.05, 0.1, 0.5, 0.75, 1}
// constant
Config_Path :: "./config/world_config.json"
Chunk_Size :: 16
Width_In_Chunk :: (World_Width + Chunk_Size - 1) / Chunk_Size
Height_In_Chunk :: (World_Height + Chunk_Size - 1) / Chunk_Size
Max_Chunk_Idx :: Width_In_Chunk * Height_In_Chunk - 1
Chunk_Idle_Thresh :: 6
Dt: f64 : 1.0 / 60.0
Dt32: f32 : 1.0 / 60.0
World_Width :: 1920 / Scale
World_Height :: 1080 / Scale
Gravity: f32 : 980
Scale :: 4
Brush_Size :: 4
Start_Time_Scale :: 5
Start_Mat :: Material.Sand
// global material constant
Material_Type_Config :: struct {
	Vy_Thresh: f32,
	Max_Vy:    f32,
	Max_Vx:    f32,
}
Powder :: Material_Type_Config{1, 8.0, 4.0}
Liquid :: Material_Type_Config{1.5, 10.0, 8.0}
// fallback config will be generated using `generator.odin`
Fallback_Conf: [Material]Material_Config = {
	.Empty  = Material_Config{},
	.Sand   = Material_Config{},
	.Dirt   = Material_Config{},
	.Water  = Material_Config{},
	.Cement = Material_Config{},
}
load_world_config :: proc(path: string) -> (res: World_Config) {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil do panic(fmt.tprintfln("Failed to load file: %v", err))
	defer delete(data)
	temp_map := make(map[string]Material_Config)
	defer delete(temp_map)
	unmarshal_err := json.unmarshal_any(data, &temp_map)
	if unmarshal_err != nil {
		fmt.eprintfln("Failed to parse config file, loaded fallback config")
		return Fallback_Conf
	}
	enum_arr: World_Config
	for k, v in temp_map {
		if var, ok := reflect.enum_from_name(Material, k); ok {
			enum_arr[var] = v
		}
	}
	return enum_arr
}
