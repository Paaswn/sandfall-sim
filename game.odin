package main

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
	mouse_wheel: Wheel_State,
	has_prev: bool
}

Wheel_State :: enum {
	Up,
	None,
	Down,
}


create_game :: proc() -> Game {
	mouse_pos := rl.GetMousePosition()
	return Game {
		sim.create_world(),
		Game_Config{sim.Brush_Size, sim.T_Scale, sim.Debug.Off, sim.Start_Mat},
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
}
