package game

import rl "vendor:raylib"

init_camera :: proc(cam: ^rl.Camera2D) {
    cam.target = {0, 0}
    cam.offset = {0, 0}
    cam.rotation = 0
    cam.zoom = 1
}