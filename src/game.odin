package main

import "core:fmt"
import "core:os"
import "core:time"
import sim "simulation"
import rl "vendor:raylib"

Game :: struct {
	world:     sim.World,
	config:    Game_Config,
	events:    Event_Queues,
	pixel_buf: []rl.Color,
	mouse:     Mouse_State,
}

Mouse_State :: struct {
	pos:         rl.Vector2,
	world:       [2]int,
	prev_world:  [2]int,
	wheel: sim.Wheel_State,
	has_prev:    bool,
}

update_mouse_state :: proc(mouse: ^Mouse_State) {
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
create_game :: proc() -> Game {
	mouse_pos := rl.GetMousePosition()
	return Game {
		sim.create_world(),
		Game_Config{sim.Brush_Size, sim.T_Scale, sim.Debug.Off, sim.Start_Mat, sim.Scale},
		make_event_queues(),
		make([]rl.Color, sim.Width * sim.Height),
		Mouse_State{mouse_pos, mouse_world(mouse_pos), mouse_world(mouse_pos), .None, false},
	}
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
}


Game_Config :: struct {
	brush_size:  int,
	time_scale:  int,
	debug_mode:  sim.Debug,
	current_mat: Material,
	window_scale: int
}
