package simulation

import "core:math"
drag_neighbor :: proc(world: ^World, source: f32, x, y: int) {

}
move_diagonal :: proc(world: ^World, x, y: int) -> bool {
    return false
}

move_side :: proc(world: ^World, x, y: int) -> bool {
    return false
}

move_down :: proc(world: ^World, x, y: int) -> bool {
    grid := world.grid
    vy := world.vel_y
    now := idx(x, y)
    step := int(math.clamp(vy[now], 1, Max_Step_Y))
    to_y := y
    for s in 1..=step {
        next_y := y + s
        if is_outside(x, y+1) || is_solid(grid, idx( x, y+1 )) do break
        to_y = next_y 
    }
    if to_y != y {
        to := idx(x, to_y)
        get_chunk(world.chunks, chunk_idx_by_wpos(x, to_y)).active_next = true
        move_cell(world, to, now)
        return true
    }
    return false
}
