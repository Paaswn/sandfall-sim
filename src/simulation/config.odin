package simulation

import "core:log"
import "core:encoding/json"
import "core:os"

// Runtime Config
TIME_SCALES: []f64 : []f64{0.01, 0.05, 0.1, 0.5, 0.75, 1}
CONFIG_PATH :: "./config/world_config.json"
// World Config
WORLD_WIDTH :: 1920 / SCALE
WORLD_HEIGHT :: 1080 / SCALE
WORLD_SIZE :: WORLD_HEIGHT * WORLD_WIDTH
// Chunk
CHUNK_SIZE :: 32
WIDTH_IN_CHUNK :: (WORLD_WIDTH + CHUNK_SIZE - 1) / CHUNK_SIZE
HEIGHT_IN_CHUNK :: (WORLD_HEIGHT + CHUNK_SIZE - 1) / CHUNK_SIZE
MAX_CHUNK_IDX :: WIDTH_IN_CHUNK * HEIGHT_IN_CHUNK - 1
CHUNK_AMOUNT :: WIDTH_IN_CHUNK * HEIGHT_IN_CHUNK

MATERIAL_AWAKE_THRESHOLD :: 4
DT: f64 : 1.0 / 60.0
DT32: f32 : 1.0 / 60.0

GRAVITY: f32 : 980
SCALE :: 4
BRUSH_SIZE :: 4
START_TIME_SCALE :: 5
START_MATERIAL : Material_ID : 2
// Global Material Constant
POWDER :: Material_Type_Config{1, 8.0, 4.0}
LIQUID :: Material_Type_Config{1.5, 10.0, 8.0}

load_world_config :: proc(path: string, sim_config: ^Simulation_Config) {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil do log.panic("Failed to load file: ", err)
	defer delete(data)
	unmarshal_err := json.unmarshal_any(data, sim_config)
	if unmarshal_err != nil {
		log.panic("Unmarshal simulation config failed ", unmarshal_err)
	}
}
