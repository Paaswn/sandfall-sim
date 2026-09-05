package app

import g "../game"
import "core:sync"
import "core:strings"
import "core:reflect"
import "../profiling"
import rd "../rendering"
import sim "../simulation"
import "core:log"
import "core:prof/spall"
import rl "vendor:raylib"

App :: struct {
	game:    g.Game,
	ui:      Ui,
	control: Control,
	texture: rl.Texture,
	logger:  log.Logger,
}

Ui :: struct {
	show: bool,
	float_ui: Float_Ui,
	bound: rl.Rectangle,
	material_selector: Listview_Control,
	edit_modes: [Edit_Modes]bool,
}

Edit_Modes :: enum {
	Time_Edit,
	Friction_Text,
	Debug_Render
}


Float_Ui :: struct {
	bound: rl.Rectangle,
	show: bool
}

Listview_Control :: struct {
	choices: cstring,
	scroll_index: i32,
	active: i32,
}

init_app :: proc(app: ^App) {

	// handle, err := os.open(
	// 	fmt.tprintf(".log/FallingSand-%v.log", time.to_unix_seconds(time.now())),
	// 	{.Write, .Create},
	// )
	// defer os.close(handle)
	// assert(err == nil, "Cannot open log file")
	// file_logger := log.create_file_logger(handle)
	// defer log.destroy_file_logger(file_logger)
	// context.logger = file_logger
	app.logger = log.create_console_logger()
	context.logger = app.logger
	when profiling.PROFILE {
		profiling.profiler = spall.context_create("profile.spall")
		backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
		profiling.prof_buffer = spall.buffer_create(backing, u32(sync.current_thread_id()))
	}
	// create g instance
	g.init_game(&app.game)
	
	// imgui.CreateContext()
	// defer imgui.DestroyContext()

	log.info("Initialized Game Struct")
}

run :: proc(a: ^App) {
	game := &a.game
	events := &a.game.events
	pixel_buf := a.game.pixel_buf
	config := &a.game.config
	debugger := &a.game.debugger
	TS := sim.Time_Scales

	// main loop
	// imgui_rl.init()
	rl.InitWindow(sim.World_Width * sim.Scale, sim.World_Height * sim.Scale, "sandfall")// defer imgui_rl.shutdown()
	rl.SetTargetFPS(120)
	rl.HideCursor()
	// create a texture buffer
	image := rl.GenImageColor(sim.World_Width, sim.World_Height, rl.BLACK)
	a.texture = rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)

	log.info("Starting Game...")
	prev := rl.GetTime()
	acc: f64 = 0
	for !rl.WindowShouldClose() {
		update_input(a)
		acc, prev = update_game(game, prev, acc)
		world := get_world(game)
		// imgui.ShowDemoWindow()
		// imgui.Render()
		// imgui_rl.render_draw_data(imgui.GetDrawData())
		rl.BeginDrawing()
		rd.render_game(a.texture, game)
		draw_ui(a)
		rl.EndDrawing()
	}
}


update_input :: proc(a: ^App) {
	update_mouse_state(&a.control.cursor)
	overlap :=
		(rl.CheckCollisionPointRec(a.control.cursor.pos, a.ui.bound) && a.ui.show) ||
		(rl.CheckCollisionPointRec(a.control.cursor.pos, a.ui.float_ui.bound) && a.ui.float_ui.show)
	if overlap {
		a.control.cursor.has_prev = false
		a.control.enable_mouse = false
	} else {
		a.control.enable_mouse = true
	}
	input_handler(&a.game, a.control, &a.control.actions)
}

get_world :: proc(game: ^g.Game) -> sim.World {
	if game.debugger.on && game.debugger.len > 0 {
		return g.current_debug_frame(game.debugger)
	}
	return game.world
}

update_game :: proc(game: ^g.Game, acc, prev: f64) -> (racc, rprev: f64 ) {
	debugger := &game.debugger
	now := rl.GetTime()
	acc := acc
	if debugger.process_next_frame {
		world := &game.world
		clear(&world.movement)
		world.tick += 1
		sim.update_grid(world)
		g.dispatch_event(world, &game.events)
		g.copy_to_frame(debugger, world^)
		g.forward_frame(debugger)
		debugger.process_next_frame = false
	} else {
		ts := sim.Time_Scales
		dt := now - prev
		acc += dt * ts[game.config.time_scale]
		for acc >= sim.Dt {
			world := &game.world
			clear(&world.movement)
			sim.update_grid(world)
			g.dispatch_event(world, &game.events)
			if debugger.on {
				g.copy_to_frame(debugger, world^)
			} else {
				g.reset_debugger(debugger)
			}
			sim.update_particles(&world.particles)
			if debugger.len < 1 {
				world.tick += 1
			}
		}
	}
	return acc, now
}

delete_app :: proc(app: ^App) {
	log.info("Closing Game...")
	log.destroy_console_logger(app.logger)
	when profiling.PROFILE {
		spall.context_destroy(&profiling.profiler)
		delete(backing)
		spall.buffer_destroy(&profiling.profiler, &profiling.prof_buffer)
	}
	rl.UnloadTexture(app.texture)
	g.delete_game(&app.game)
}

init_ui :: proc(ui: ^Ui)  {
	material_choices, ok := strings.join(reflect.enum_field_names(sim.Material), ";")
	cmaterial_choices := strings.clone_to_cstring(material_choices)
	delete(material_choices)
	assert(ok == nil)
	ui.show = false
	ui.material_selector = {cmaterial_choices ,0,-1 }
	ui.float_ui = {{0, 0, 200, 100 }, false }
	ui.edit_modes =  [Edit_Modes]bool {
		.Time_Edit = false,
		.Friction_Text = false,
		.Debug_Render = false
	}
	ui.bound =  {10, 10, 250, 600}
}

delete_ui :: proc(ui: ^Ui) {
	delete(ui.material_selector.choices)
}
