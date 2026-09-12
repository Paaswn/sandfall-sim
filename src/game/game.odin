package game

import sim "../simulation"
import "core:fmt"
import "core:log"
import rl "vendor:raylib"

Game :: struct {
	simulation:     sim.Simulation,
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
	frames: [Debugger_Size]sim.Simulation,
	on:     bool,
	head:   u16,
	cursor: u16,
	tail:   u16,
	len:    u16,
	process_next_frame: bool
}


init_debugger :: proc(debugger: ^Debugger) {
	for &df in debugger.frames {
		sim.init_sim(&df)
	}
}

delete_debugger :: proc(debugger: ^Debugger) {
	for &df in debugger.frames {
		sim.destroy_sim(&df)
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

current_debug_frame :: proc(debugger: ^Debugger) -> ^sim.Simulation {
    return &debugger.frames[debugger.cursor]
}

first_debug_frame :: proc(debugger: ^Debugger) -> ^sim.Simulation {
    return &debugger.frames[debugger.head]
}

last_debug_frame :: proc(debugger: ^Debugger) -> ^sim.Simulation {
    return &debugger.frames[debugger.tail]
}
copy_to_frame :: proc(debugger: ^Debugger, simulation: ^sim.Simulation) {
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
	frame.tick = simulation.tick
	frame.config = simulation.config
	resize(&frame.cell_traces, len(simulation.cell_traces))
	copy(frame.cell_traces[:], simulation.cell_traces[:])
	copy(frame.chunks, simulation.chunks)
	copy(frame.frame, simulation.frame)
	for i in 0..<len(simulation.world) {
	    frame.world[i] = simulation.world[i]
	}
	//
}


hot_reload :: proc(world: ^sim.Simulation) {
	log.info("Hot reload materials' config!")
	sim.load_world_config(sim.CONFIG_PATH, &world.config)
}

init_game :: proc(game: ^Game) {
    init_debugger(&game.debugger)
	sim.init_sim(&game.simulation)
	init_game_config(game)
	game.events = make_event_queues()
	game.pixel_buf = make([]rl.Color, sim.WORLD_WIDTH * sim.WORLD_HEIGHT)
}

init_game_config :: proc(game: ^Game) {
	game.config = {
			false,
			sim.BRUSH_SIZE,
			sim.START_TIME_SCALE,
			sim.Debug.Off,
			false,
			sim.START_MATERIAL,
			sim.SCALE,
			{0, .Brush, nil},
		}
}
world_cursor :: proc(mouse_pos: rl.Vector2) -> sim.World_Pos {
	return sim.World_Pos(mouse_pos) / sim.SCALE
}

destroy_game :: proc(game: ^Game) {
    delete_debugger(&game.debugger)
	sim.destroy_sim(&game.simulation)
	delete_event_queues(&game.events)
	delete(game.pixel_buf)
}

Game_Config :: struct {
	show_material_movement: bool,
	brush_size:             int,
	time_scale:             i32,
	debug_render:           sim.Debug,
	show_chunk_border:      bool,
	current_mat:            sim.Material_ID,
	window_scale:           int,
	tool_man:               Tool_Manager,
}