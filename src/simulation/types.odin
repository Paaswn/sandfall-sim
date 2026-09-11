package simulation

import "core:math/fixed"
import rl "vendor:raylib"

Update_Context :: struct {
	chunk: ^Chunk,
	now:   int,
	cpos:  Chunk_Pos,
	wpos:  World_Pos,
	lpos:  Local_Pos,
}

Color :: [4]u8
IVec2 :: [2]int
Chunk_Pos :: distinct IVec2
World_Pos :: distinct IVec2
Local_Pos :: distinct IVec2

World_Index :: i32
Chunk_Index :: i32

Material_Type :: enum u8 {
	Liquid, // move without thresh (side/slide thresh =0)
	Powder, // move with thresh
	Hard, // static material that can't be damaged by any game object
	Semi_Hard, // static material that can be slightly damaged by game object
	Empty,
}

Mat_Types :: bit_set[Material_Type]

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

Simulation_Config :: []Material_Config
Material_Config :: struct {
	name:           string,
	type:           Material_Type,
	color:          Color,
	variance:       u8,
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
