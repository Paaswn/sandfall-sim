package simulation

import "core:log"
import "core:encoding/json"
import "core:os"

// Runtime Config
Time_Scales: []f64 : []f64{0.01, 0.05, 0.1, 0.5, 0.75, 1}
Config_Path :: "./config/world_config.json"
// World Config
World_Width :: 1920 / Scale
World_Height :: 1080 / Scale
World_Size :: World_Height * World_Width
// Chunk
Chunk_Size :: 32
Width_In_Chunk :: (World_Width + Chunk_Size - 1) / Chunk_Size
Height_In_Chunk :: (World_Height + Chunk_Size - 1) / Chunk_Size
Max_Chunk_Idx :: Width_In_Chunk * Height_In_Chunk - 1
Chunk_Amount :: Width_In_Chunk * Height_In_Chunk

Material_Awake_Threshold :: 4
Dt: f64 : 1.0 / 60.0
Dt32: f32 : 1.0 / 60.0

Gravity: f32 : 980
Scale :: 4
Brush_Size :: 4
Start_Time_Scale :: 5
Start_Mat : Material_ID : 2
// Global Material Constant
Powder :: Material_Type_Config{1, 8.0, 4.0}
Liquid :: Material_Type_Config{1.5, 10.0, 8.0}

load_world_config :: proc(path: string, sim_config: ^Simulation_Config) {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil do log.panic("Failed to load file: ", err)
	defer delete(data)
	unmarshal_err := json.unmarshal_any(data, sim_config)
	if unmarshal_err != nil {
		log.panic("Unmarshal simulation config failed ", unmarshal_err)
	}
}
