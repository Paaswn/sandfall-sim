package main

import sim "simulation"
import rl "vendor:raylib"

main :: proc() {
	// events queue init
	events := sim.make_event_queues()
	defer sim.delete_event_queues(&events)

	// world init
	world := sim.create_world()
	defer sim.delete_world(&world)

	pixel_buf := make([]rl.Color, sim.Width * sim.Height)
	defer delete(pixel_buf)
	// raylib window init
	rl.InitWindow(sim.Width * sim.Scale, sim.Height * sim.Scale, "sandfall")
	rl.SetTargetFPS(120)
	rl.HideCursor()
	// create a texture buffer
	image := rl.GenImageColor(sim.Width, sim.Height, rl.BLACK)
	texture := rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	defer rl.UnloadTexture(texture)

	// main loop
	prev := rl.GetTime()
	acc: f64 = 0
	tick: u64 = 0
	for !rl.WindowShouldClose() {
		now := rl.GetTime()
		dt := now - prev
		acc += dt * sim.t_scale
		prev = now
		sim.track_input(&events)
		for acc >= sim.Dt {
			tick += 1
			sim.event_listener(&world, &events)
			sim.update(&world, tick)
			acc -= sim.Dt
		}
		build_pixel_buf(&world, pixel_buf)
		rl.UpdateTexture(texture, raw_data(pixel_buf))
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTextureEx(texture, {0, 0}, 0, sim.Scale, rl.WHITE)
		if sim.debug_mode == .Chunk {
			render_debug_chunk(&world)
		}
		render_brush(int(rl.GetMouseX() / sim.Scale), int(rl.GetMouseY() / sim.Scale))
		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}
}
