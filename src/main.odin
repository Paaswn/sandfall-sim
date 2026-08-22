package main

import "profiling"
import "core:prof/spall"
import "core:sync"
import "game"
import sim "simulation"
import rl "vendor:raylib"

main :: proc() {
    when profiling.PROFILE {
        profiling.profiler = spall.context_create("profile.spall")
       	defer spall.context_destroy(&profiling.profiler)
       	backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
       	defer delete(backing)
        
       	profiling.prof_buffer = spall.buffer_create(backing, u32(sync.current_thread_id()))
       	defer spall.buffer_destroy(&profiling.profiler, &profiling.prof_buffer)
    }
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

	instance: game.Game
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
		overlap :=
			(rl.CheckCollisionPointRec(instance.mouse.pos, instance.debug_ui.bound) &&
				instance.debug_ui.show) ||
			(rl.CheckCollisionPointRec(instance.mouse.pos, instance.debug_ui.float_uis.bound) &&
					instance.debug_ui.float_uis.show)
		if overlap {
			instance.mouse.has_prev = false
		} else {
			game.mouse_handler(&instance)
		}

		game.keyboard_handler(&instance)

		for acc >= sim.Dt {
			game.event_listener(world, events)
			sim.update_grid(world)
			sim.update_particles(&world.particles)
			acc -= sim.Dt
			world.tick += 1
		}
		when ODIN_DEBUG {
			game.build_pixel_buf(&instance)
			rl.UpdateTexture(texture, raw_data(pixel_buf))
		} else {
			rl.UpdateTexture(texture, raw_data(world.color))
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTextureEx(texture, {0, 0}, 0, sim.Scale, rl.WHITE)
		game.render_particles(world.particles)

		if config.show_chunk_border {
			game.render_debug_chunk(world)
		}

		if instance.debug_ui.show {
			game.draw_ui(&instance)
			rl.DrawFPS(100, 20)
		}

		if instance.debug_ui.float_uis.show {
			game.material_list_selector(
				config,
				&instance.debug_ui,
				instance.debug_ui.float_uis.bound,
			)
		}

		game.render_tool(config, &instance.mouse)
		rl.EndDrawing()
	}
}


on_window_resize :: proc() {
	if rl.IsWindowResized() {
		rl.SetWindowSize(rl.GetRenderWidth(), rl.GetRenderHeight())
	}
}

