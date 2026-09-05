package game

import sim "../simulation"
import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:slice"
import rl "vendor:raylib"

Game :: struct {
	world:     sim.World,
	config:    Game_Config,
	events:    Event_Queues,
	pixel_buf: []rl.Color,
	debugger: Debugger
}

// maybe add mouse click here

Tool :: enum {
	Pipette,
	Brush,
}
Tool_Manager :: struct {
	just_switched: u8,
	curr_tool:     Tool,
	prev_tool:     Tool,
}

Debugger_Size :: 16
Debugger :: struct {
	frames: [Debugger_Size]World,
	on:     bool,
	head:   u16,
	cursor: u16,
	tail:   u16,
	len:    u16,
	process_next_frame: bool
}


init_debugger :: proc(debugger: ^Debugger) {
	for &df in debugger.frames {
		sim.create_world(&df)
	}
}

delete_debugger :: proc(debugger: ^Debugger) {
	for &df in debugger.frames {
		sim.delete_world(&df)
	}
}

reset_debugger :: proc(debugger: ^Debugger) {
    debugger.len = 0
}

backward_frame :: proc(debugger: ^Debugger, frame: u16 = 1) {
    debugger.process_next_frame = false
    if debugger.cursor == debugger.head || debugger.len <= 1 {
        return
    }
	debugger.cursor = (debugger.cursor + Debugger_Size - frame) % Debugger_Size
}

forward_frame :: proc(debugger: ^Debugger, frame: u16 = 1) {
    if debugger.cursor == debugger.tail || debugger.len <= 1 {
        debugger.process_next_frame = true
        return
    }
	debugger.cursor = (debugger.cursor + frame) % Debugger_Size
}

current_debug_frame :: proc(debugger: Debugger) -> sim.World {
    return debugger.frames[debugger.cursor]
}

first_debug_frame :: proc(debugger: Debugger) -> sim.World {
    return debugger.frames[debugger.head]
}

last_debug_frame :: proc(debugger: Debugger) -> sim.World {
    return debugger.frames[debugger.tail]
}
copy_to_frame :: proc(debugger: ^Debugger, world: World) {
    if debugger.len == 0 {
        debugger.head = 0
        debugger.tail = 0
        debugger.cursor = 0
    } else {
        debugger.tail = (debugger.tail + 1) % Debugger_Size
    }
    if debugger.len < Debugger_Size {
        debugger.len += 1
    } else {
        debugger.head = (debugger.head + 1) % Debugger_Size
    }
	frame := &debugger.frames[debugger.tail]

	// copy current world to frame
	frame.tick = world.tick
	frame.config = world.config
	resize(&frame.movement, len(world.movement))
	copy(frame.movement[:], world.movement[:])
	copy(frame.chunks, world.chunks)
	copy(frame.color, world.color)
	copy(frame.grid, world.grid)
	copy(frame.side, world.side)
	copy(frame.updated, world.updated)
	copy(frame.vel_x, world.vel_x)
	copy(frame.vel_y, world.vel_y)
	//
}


hot_reload :: proc(world: ^sim.World) {
	log.info("Hot reload materials' config!")
	world.config = sim.load_world_config(sim.Config_Path)
}

init_game :: proc(game: ^Game) {
    init_debugger(&game.debugger)
	sim.create_world(&game.world)
	game.config = Game_Config {
		false,
		sim.Brush_Size,
		sim.Start_Time_Scale,
		sim.Debug.Off,
		false,
		sim.Start_Mat,
		sim.Scale,
		{0, .Brush, nil},
	}
	game.events = make_event_queues()
	game.pixel_buf = make([]rl.Color, sim.World_Width * sim.World_Height)
}

world_cursor :: proc(mouse_pos: rl.Vector2) -> sim.World_Pos {
	return sim.World_Pos(mouse_pos) / sim.Scale
}

delete_game :: proc(game: ^Game) {
    delete_debugger(&game.debugger)
	sim.delete_world(&game.world)
	delete_event_queues(&game.events)
	delete(game.pixel_buf)
}

Game_Config :: struct {
	show_material_movement: bool,
	brush_size:             int,
	time_scale:             i32,
	debug_render:           sim.Debug,
	show_chunk_border:      bool,
	current_mat:            Material,
	window_scale:           int,
	tool_man:               Tool_Manager,
}
