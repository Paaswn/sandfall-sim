package game

import sim "../simulation"
import "core:fmt"
import rl "vendor:raylib"

Game :: struct {
	world:     sim.World,
	config:    Game_Config,
	events:    Event_Queues,
	pixel_buf: []rl.Color,
	mouse:     Mouse,
	debug_ui:  Ui_Manager,
}

// maybe add mouse click here
Mouse :: struct {
	pos:        rl.Vector2,
	world:      [2]int,
	prev_world: [2]int,
	wheel:      Wheel_State,
	has_prev:   bool,
}

Tool :: enum {
	Pipette,
	Brush
}

Tool_Manager :: struct {
	just_switched: u8,
	curr_tool: Tool,
	prev_tool: Tool,
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
	world.config = sim.load_world_config(sim.Config_Path)
}

create_game :: proc(instance: ^Game) {
		instance.world = sim.create_world()
		instance.config = Game_Config{sim.Brush_Size, sim.Start_Time_Scale, sim.Debug.Off, false, sim.Start_Mat, sim.Scale, {0, .Brush, nil}}
		instance.events = make_event_queues()
		instance.pixel_buf = make([]rl.Color, sim.World_Width * sim.World_Height)
		instance.mouse = Mouse{{}, {}, {}, .None, false}
		instance.debug_ui = create_ui()
}

mouse_world :: proc(mouse_pos: rl.Vector2) -> [2]int {
	mouse_scale_x := int(mouse_pos.x / sim.Scale)
	mouse_scale_y := int(mouse_pos.y / sim.Scale)
	return [2]int{mouse_scale_x, mouse_scale_y}
}

delete_game :: proc(game: ^Game) {
	sim.delete_world(&game.world)
	delete_event_queues(&game.events)
	delete(game.pixel_buf)
	delete_ui(&game.debug_ui)
}

Game_Config :: struct {
	brush_size:   int,
	time_scale:   i32,
	debug_render:   sim.Debug,
	show_chunk_border: bool,
	current_mat:  Material,
	window_scale: int,
	tool_man: Tool_Manager
}
