package app
import g "../game"
import sim "../simulation"
import "core:fmt"
import "core:reflect"
import "core:strings"
import rl "vendor:raylib"


draw_debug_chunk :: proc(world: sim.World) {
	@(static) num: [10]cstring = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
	for &chunk, i in world.chunks {
		if sim.chunk_active(&chunk, world.tick) {
			S :: sim.Scale
			bound, ok := chunk.next_bound.?
			cp := sim.to_chunk_pos(i)
			pos := sim.to_world_pos(cp, {0, 0})
			color := rl.GREEN
			color.a = 89
			rl.DrawRectangleLines(
				i32(pos.x * S),
				i32(pos.y * S),
				i32(sim.Chunk_Size * S),
				i32(sim.Chunk_Size * S),
				color,
			)
			// if !ok do continue
			// CS := sim.Chunk_Size
			j := world.tick - chunk.last_updated_tick
			to_reset: cstring
			chunk_age: cstring
			if j >= len(num) {
				chunk_age = fmt.ctprint(j)
			} else {
				chunk_age = num[j]
			}
			rl.DrawText(
				fmt.ctprint(chunk_age),
				i32((pos.x + sim.Chunk_Size / 2) * S),
				i32((pos.y + sim.Chunk_Size / 2) * S),
				20,
				rl.WHITE,
			)
			ok or_continue
			pos = sim.to_world_pos(cp, {bound.x, bound.y})
			x, y := pos.x, pos.y
			pos2 := sim.to_world_pos(cp, {bound.x2, bound.y2})
			x2, y2 := pos2.x, pos2.y
			rl.DrawRectangleLines(
				i32(x * S),
				i32(y * S),
				i32((x2 - x + 1) * S),
				i32((y2 - y + 1) * S),
				rl.RED,
			)
		}
	}
}
draw_ui :: proc(app: ^App) {
	game := &app.game
	if game.config.show_material_movement {
		for p in game.world.movement {
			np := sim.Scale * p
			rl.DrawLine(i32(np.x) + 2, i32(np.y) + 2, i32(np.z) + 2, i32(np.w) + 2, rl.PINK)
		}
	}

	for i: i32 = 0; i <= sim.World_Height; i += sim.Chunk_Size {
		rl.DrawLine(
			0,
			i * sim.Scale,
			sim.World_Width * sim.Scale,
			i * sim.Scale,
			{255, 255, 255, 89},
		)
	}
	for i: i32 = 0; i <= sim.World_Width; i += sim.Chunk_Size {
		rl.DrawLine(
			i * sim.Scale,
			0,
			i * sim.Scale,
			sim.World_Height * sim.Scale,
			{255, 255, 255, 89},
		)
	}
	if game.config.show_chunk_border {
		draw_debug_chunk(game.world)
	}

	if game.debugger.on {
		rl.DrawText(
			fmt.ctprintf(
				"Oldest Tick:  %v\nCurrent Tick: %v\nLatest Tick:  %v\nMain Tick:    %v",
				g.first_debug_frame(&game.debugger).tick,
				g.current_debug_frame(&game.debugger).tick,
				g.last_debug_frame(&game.debugger).tick,
				game.world.tick,
			),
			500,
			500,
			20,
			rl.WHITE,
		)
	}
	if app.ui.show {
		draw_debug_ui(game, &app.ui)
		rl.DrawFPS(100, 20)
	}

	if app.ui.float_ui.show {
		material_list_selector(&game.config, &app.ui, app.ui.float_ui.bound)
	}
	draw_tool(game.config, app.control.cursor)

}
draw_tool :: proc(config: g.Game_Config, mouse: Cursor) {
	switch config.tool_man.curr_tool {
	case .Pipette:
		draw_pipette(config, mouse)
	case .Brush:
		draw_brush(config, mouse)
	}
}

draw_pipette :: proc(config: g.Game_Config, mouse: Cursor) {
	rl.DrawRectangle(
		i32(mouse.world.x * sim.Scale),
		i32(mouse.world.y * sim.Scale),
		i32(sim.Scale),
		i32(sim.Scale),
		rl.WHITE,
	)
}

draw_brush :: proc(config: g.Game_Config, mouse: Cursor) {

	rl.DrawRectangle(
		i32(mouse.world.x * sim.Scale),
		i32(mouse.world.y * sim.Scale),
		i32(sim.Scale),
		i32(sim.Scale),
		rl.WHITE,
	)
	if config.brush_size == 0 do return

	for y in mouse.world.y - config.brush_size ..= mouse.world.y + config.brush_size {
		for x in mouse.world.x - config.brush_size ..= mouse.world.x + config.brush_size {
			if sim.is_outside(x, y) {
				continue
			}
			dx := x - mouse.world.x
			dy := y - mouse.world.y
			dist2 := dx * dx + dy * dy
			outer := config.brush_size * config.brush_size
			inner := (config.brush_size - 1) * (config.brush_size - 1)
			if dist2 < outer && dist2 >= inner {
				rl.DrawRectangle(
					i32(x * sim.Scale),
					i32(y * sim.Scale),
					i32(sim.Scale),
					i32(sim.Scale),
					rl.WHITE,
				)
			}
		}
	}
}

draw_debug_ui :: proc(game: ^g.Game, ui: ^Ui) {
	conf := &game.config
	edit_modes := &ui.edit_modes
	rl.GuiPanel(ui.bound, "Debug Panel")
	// rl.DrawRectangleRoundedLines(, 0.1, 20, rl.WHITE)
	material_list_selector(conf, ui, {20, 50, 200, 100})
	debug_mode_as_int := i32(conf.debug_render)
	if rl.GuiDropdownBox(
		{20, 20, 50, 25},
		"Off;Vy;Vx",
		&debug_mode_as_int,
		edit_modes[.Debug_Render],
	) {
		edit_modes[.Debug_Render] = !edit_modes[.Debug_Render]
		conf.debug_render = sim.Debug(debug_mode_as_int)
	}
	if rl.GuiDropdownBox(
		{20, 160, 50, 25},
		"0.01;0.05;0.1;0.5;0.75;1",
		&conf.time_scale,
		edit_modes[.Time_Edit],
	) {
		edit_modes[.Time_Edit] = !edit_modes[.Time_Edit]
	}

	rl.GuiCheckBox({20, 190, 50, 25}, "Show Chunk Border", &conf.show_chunk_border)

}

material_list_selector :: #force_inline proc(
	conf: ^g.Game_Config,
	dbg_ui: ^Ui,
	rect: rl.Rectangle,
) {
	mat_as_int := i32(conf.current_mat)
	selected := rl.GuiListView(
		rect,
		dbg_ui.material_selector.choices,
		&dbg_ui.material_selector.scroll_index,
		&mat_as_int,
	)
	if mat_as_int < 0 do mat_as_int = 0
	conf.current_mat = sim.Material(mat_as_int)
}
