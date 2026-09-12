package simulation

Simulation_Config :: []Material_Config
Cell_Traces :: [dynamic][4]int
World :: #soa[]Cell

Simulation :: struct {
	tick:      u32,
	world:     World,
	chunks:    []Chunk,
	frame:     []Color,
	config:    Simulation_Config,
	cell_traces:  Cell_Traces,
}

init_sim :: proc(sim: ^Simulation) {
    sim.tick = 0
    sim.world = make_soa(#soa[]Cell, WORLD_SIZE)
    sim.chunks = make([]Chunk, CHUNK_AMOUNT)
    sim.cell_traces = make(Cell_Traces)
    sim.frame = make([]Color, WORLD_SIZE)
    load_world_config(CONFIG_PATH, &sim.config)
}

destroy_sim :: proc(sim: ^Simulation) {
    delete(sim.frame)
    delete_soa(sim.world)
    delete(sim.chunks)
    delete(sim.cell_traces)
    delete(sim.config)
}