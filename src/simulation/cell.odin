package simulation

Cell :: bit_field u32 {
	id: Material_ID | 16,
	variance : u8 | 4,
	side: i8 | 2,
}

Property :: bit_field u32 {
	id: Material_ID | 16,
	variance : u8 | 4,
	side: i8 | 2,
}

Cell2 :: struct {
    using property: Property,
    update_tick: u32,
    color: Color,
    vx: f32,
    vy: f32,
}
cell_at :: proc(world: World, i: int) -> ^Cell {
    return &world.grid[i]
}

id_at :: proc(world: World, i: int) -> Material_ID {
    return world.grid[i].id
}

get_cell_color :: proc(world: World, cell: Cell) -> Color {
    return world.config[cell.id].color
}

cell_type_match :: proc(world: World, i: int, type: Material_Type) -> bool {
	return config_of(world, i).type == type
}

cell_type :: proc(world: World, i: int, ) -> Material_Type {
	return world.config[id_at( world, i )].type
}

type_of_id :: proc(world: World, id: Material_ID) -> Material_Type {
    return world.config[id].type
}

type_of_id_match :: proc(world: World, id: Material_ID, type: Material_Type) -> bool {
    return world.config[id].type == type
}
config_of :: proc(world: World, idx: int) -> Material_Config {
	return world.config[id_at(world, idx)]
}
