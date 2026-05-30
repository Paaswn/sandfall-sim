package simulation

import "core:math"
import "core:fmt"
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
        if is_outside(x, y+s) || is_solid(grid, idx( x, y+s )) do break
        to_y = next_y 
    }
    if to_y != y {
        to := idx(x, to_y)
        wake_neighbor_chunk(world.chunks, x, to_y, 1)
        vy[to] = vy[now]
        move_cell(world, to, now)
        return true
    }
    return false
}
