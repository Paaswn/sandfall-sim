package simulation

Property :: bit_field u32 {
	id: Material_ID | 16,
	variance : u8 | 4,
	side: i8 | 2,
}

Cell :: struct {
    using property: Property,
    update_tick: u32,
    vel: [2]f32,
}
cell_at :: proc(world: World, i: int) -> Cell {
    return world[i]
}

id_at :: proc(world: World, i: int) -> Material_ID {
    return world[i].id
}

get_cell_color :: proc(sim: Simulation, cell: Cell) -> Color {
    return sim.config[cell.id].color
}

color_of :: proc(sim: Simulation, id: Material_ID) -> Color {
    return sim.config[id].color
}

config_of :: proc(sim: Simulation, idx: int) -> Material_Config {
	return sim.config[id_at(sim.world, idx)]
}

cell_type_match :: proc(sim: Simulation, i: int, type: Material_Type) -> bool {
	return config_of(sim, i).type == type
}

cell_type :: proc(sim: Simulation, i: int, ) -> Material_Type {
	return sim.config[id_at(sim.world, i )].type
}

type_of_id :: proc(sim: Simulation, id: Material_ID) -> Material_Type {
    return sim.config[id].type
}

type_of_id_match :: proc(sim: Simulation, id: Material_ID, type: Material_Type) -> bool {
    return sim.config[id].type == type
}
