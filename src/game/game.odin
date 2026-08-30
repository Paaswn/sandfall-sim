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
	mouse:     Mouse,
	debug_ui:  Ui_Manager,
	debugger:  Debugger,
}

// maybe add mouse click here
Mouse :: struct {
	pos:        rl.Vector2,
	world:      sim.World_Pos,
	prev_world: sim.World_Pos,
	wheel:      Wheel_State,
	has_prev:   bool,
}

Tool :: enum {
	Pipette,
	Brush,
}
Tool_Manager :: struct {
	just_switched: u8,
	curr_tool:     Tool,
	prev_tool:     Tool,
}

Debugger_Buf_Size :: 16
Debugger :: struct {
    on: bool,
	current_frame: i16,
	frames:      [Debugger_Buf_Size]World,
	write_index: i16,
	len: u16
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
    debugger.write_index = 0;
    debugger.current_frame = 0;
    debugger.len = 0;
}

backward_frame :: proc(debugger: ^Debugger, frame :i16 = 1) {
    debugger.current_frame = ( debugger.current_frame + Debugger_Buf_Size - frame ) % Debugger_Buf_Size
}

forward_frame :: proc(debugger: ^Debugger, frame: i16 = 1) {
    debugger.current_frame = ( debugger.current_frame + frame ) % Debugger_Buf_Size
}

copy_to_frame :: proc(debugger: ^Debugger, world: ^World) {
	frame := &debugger.frames[debugger.write_index]
	frame.tick = world.tick
	frame.config = world.config
	copy(frame.movement[:], world.movement[:])
	copy(frame.chunks, world.chunks)
	copy(frame.color, world.color)
	copy(frame.grid, world.grid)
	copy(frame.side, world.side)
	copy(frame.updated, world.updated)
	copy(frame.vel_x, world.vel_x)
	copy(frame.vel_y, world.vel_y)
	debugger.len = min(debugger.len+1, Debugger_Buf_Size)
	debugger.write_index += 1;
	if debugger.write_index >= Debugger_Buf_Size do debugger.write_index = 0
}
update_mouse_state :: proc(mouse: ^Mouse) {
	mouse_pos := rl.GetMousePosition()
	mouse.world = mouse_world(mouse_pos)
	mouse.pos = mouse_pos
	if rl.GetMouseWheelMove() < 0 do mouse.wheel = .Down
	else if rl.GetMouseWheelMove() > 0 do mouse.wheel = .Up
	else do mouse.wheel = .None
}

hot_reload :: proc(world: ^sim.World) {
	log.info("Hot reload materials' config!")
	world.config = sim.load_world_config(sim.Config_Path)
}

create_game :: proc(instance: ^Game) {
	debugger: Debugger
	init_debugger(&debugger)
	sim.create_world(&instance.world)
	instance.config = Game_Config {
		false,
		sim.Brush_Size,
		sim.Start_Time_Scale,
		sim.Debug.Off,
		false,
		sim.Start_Mat,
		sim.Scale,
		{0, .Brush, nil},
	}
	instance.debugger = debugger
	instance.events = make_event_queues()
	instance.pixel_buf = make([]rl.Color, sim.World_Width * sim.World_Height)
	instance.mouse = Mouse{{}, {}, {}, .None, false}
	instance.debug_ui = create_ui()
}

mouse_world :: proc(mouse_pos: rl.Vector2) -> sim.World_Pos {
	return sim.World_Pos(mouse_pos) / sim.Scale
}

delete_game :: proc(game: ^Game) {
	sim.delete_world(&game.world)
	delete_event_queues(&game.events)
	delete(game.pixel_buf)
	delete_ui(&game.debug_ui)
	delete_debugger(&game.debugger)
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
