package simulation

import rl "vendor:raylib"
import "core:math/fixed"

World :: struct {
	tick:      u32,
	vel_x:     []f32,
	vel_y:     []f32,
	grid:      []Material, // will be packed into mat id
	color:     []rl.Color,
	chunks:    []Chunk,
	updated:   []u32,
	side:      []int, // will be packed inside mat id
	particles: [dynamic]Particle,
	config:    World_Config,
	movement: [dynamic][4]int,
}

Update_Context :: struct {
	chunk: ^Chunk,
	now: int,
	cpos: Chunk_Pos,
	wpos: World_Pos,
	lpos: Local_Pos
}

IVec2 :: [2]int
Chunk_Pos :: distinct IVec2
World_Pos :: distinct IVec2
Local_Pos :: distinct IVec2

World_Index :: u32
Chunk_Index :: u32

World_Config :: [Material]Material_Config

Material_Type :: enum u8 {
	Liquid, // move without thresh (side/slide thresh =0)
	Powder, // move with thresh
	Hard, // static material that can't be damaged by any game object
	Semi_Hard, // static material that can be slightly damaged by game object
}

Debug :: enum {
	Off,
	Velocity_Y,
	Velocity_X,
}

Bound :: struct {
	x, y, x2, y2: int,
}

Chunk :: struct {
	next_bound:        Maybe(Bound),
	last_updated_tick: u32,
	// active:            bool,
}

Material_Type_Config :: struct {
	Vy_Thresh: f32,
	Max_Vy:    f32,
	Max_Vx:    f32,
}

Material_Config :: struct {
	type:           Material_Type,
	down_acc:       f32,
	slide_thresh:   f32,
	side_thresh:    f32,
	friction:       f32,
	damp:           f32,
	impact_to_side: f32,
	impact_thresh:  f32,
	slide_drag:     f32,
	fall_drag:      f32,
}

Velocity :: distinct fixed.Fixed(i16, 6)
Material_ID :: distinct u16
/*
	cell ( used to be enum named Material ) currently have

	ID
	
	VARIANCE *of color*

	SIDE

	ACTIVE

	TEMPERATURE *tbd*
*/
Cell :: bit_field u32 {
	id: Material_ID | 16,
	variance : u8 | 4,
	side: i8 | 2,
	active: bool | 1,
}