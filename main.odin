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

	pixel_buf := make([]rl.Color, sim.WIDTH * sim.HEIGHT)
	defer delete(pixel_buf)
	// raylib window init
	rl.InitWindow(sim.WIDTH * sim.SCALE, sim.HEIGHT * sim.SCALE, "sandfall")
	rl.SetTargetFPS(120)
	rl.HideCursor()
	// create a texture buffer
	image := rl.GenImageColor(sim.WIDTH, sim.HEIGHT, rl.BLACK)
	texture := rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	defer rl.UnloadTexture(texture)

	// main loop
	prev := rl.GetTime()
	acc: f64 = 0
	tick := 0
	for !rl.WindowShouldClose() {
		now := rl.GetTime()
		dt := now - prev
		acc += dt * sim.t_scale
		prev = now
		sim.track_mouse(&events)
		sim.track_kb()
		for acc >= sim.DT {
			tick += 1
			if tick == 3 do tick = 1
			sim.event_listener(&world, &events)
			sim.update(&world, tick)
			acc -= sim.DT
		}
		build_pixel_buf(&world, pixel_buf)
		rl.UpdateTexture(texture, raw_data(pixel_buf))
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTextureEx(texture, {0, 0}, 0, sim.SCALE, rl.WHITE)
		render_brush(int(rl.GetMouseX() / sim.SCALE), int(rl.GetMouseY() / sim.SCALE))
		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}
}
