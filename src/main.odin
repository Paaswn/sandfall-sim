package main

import "game"
import sim "simulation"
import rl "vendor:raylib"
import "core:fmt"


main :: proc() {
	// raylib window init
	rl.InitWindow(sim.World_Width * sim.Scale, sim.World_Height * sim.Scale, "sandfall")
	rl.SetTargetFPS(120)
	rl.HideCursor()
	// create a texture buffer
	image := rl.GenImageColor(sim.World_Width, sim.World_Height, rl.BLACK)
	texture := rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	defer rl.UnloadTexture(texture)

	// create instance session

	instance : game.Game
	game.create_game(&instance)
	defer game.delete_game(&instance)
	world := &instance.world
	events := &instance.events
	pixel_buf := instance.pixel_buf
	config := &instance.config
	TS := sim.T_Scales

	// main loop
	prev := rl.GetTime()
	acc: f64 = 0

	for !rl.WindowShouldClose() {

		now := rl.GetTime()
		dt := now - prev
		acc += dt * TS[config.time_scale]
		prev = now
		game.update_mouse_state(&instance.mouse)
		if !rl.CheckCollisionPointRec(instance.mouse.pos, instance.debug_ui.bound) || !instance.debug_ui.show {
			game.mouse_handler(&events.spawn, &instance.mouse, config)
		} else {
			instance.mouse.has_prev = false
		}

		game.keyboard_handler(&instance)

		for acc >= sim.Dt {
			game.event_listener(world, events)
			sim.update(world)
			acc -= sim.Dt
			world.tick += 1
		}

		build_pixel_buf(&instance)
		rl.UpdateTexture(texture, raw_data(pixel_buf))
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTextureEx(texture, {0, 0}, 0, sim.Scale, rl.WHITE)

		if config.show_chunk_border {
			render_debug_chunk(world)
		}

		if instance.debug_ui.show {
			game.ui_draw(&instance)
			rl.DrawFPS(100, 20)
		}

		if instance.debug_ui.float_uis.show {
			game.material_list_selector(config, &instance.debug_ui, instance.debug_ui.float_uis.bound)
		}

		render_brush(config, &instance.mouse)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}
}


on_window_resize :: proc() {
	if rl.IsWindowResized() {
		rl.SetWindowSize(rl.GetRenderWidth(), rl.GetRenderHeight())
	}
}
