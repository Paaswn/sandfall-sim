package main

import sim "simulation"
import rl "vendor:raylib"


main :: proc() {
	// raylib window init
	rl.InitWindow(sim.Width * sim.Scale, sim.Height * sim.Scale, "sandfall")
	rl.SetTargetFPS(120)
	rl.HideCursor()
	// create a texture buffer
	image := rl.GenImageColor(sim.Width, sim.Height, rl.BLACK)
	texture := rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	defer rl.UnloadTexture(texture)

	// create game session
	game := create_game()
	defer delete_game(&game)
	world := &game.world
	events := &game.events
	pixel_buf := game.pixel_buf
	config := &game.config
	TS := sim.T_Scales
	
	// main loop
	prev := rl.GetTime()
	acc: f64 = 0
	tick: u64 = 0
	for !rl.WindowShouldClose() {
		now := rl.GetTime()
		dt := now - prev
		acc += dt * TS[config.time_scale]
		prev = now
		mouse_pos := rl.GetMousePosition()
		game.mouse.world = mouse_world(mouse_pos)
		game.mouse.pos = mouse_pos
		track_input(&game)
		for acc >= sim.Dt {
			tick += 1
			event_listener(world, events)
			sim.update(world, tick)
			acc -= sim.Dt
		}
		build_pixel_buf(&game)
		rl.UpdateTexture(texture, raw_data(pixel_buf))
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTextureEx(texture, {0, 0}, 0, sim.Scale, rl.WHITE)
		if config.debug_mode == .Chunk {
			render_debug_chunk(world)
		}
		render_brush(config, game.mouse)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}
}
