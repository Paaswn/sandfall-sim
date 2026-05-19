package main

// runtime config
spawn_mat := Material.Sand
select_explosive := false
spawn_radius := 4
// constant
DT: f64 : 1.0 / 60.0
WIDTH :: 480
HEIGHT :: 270
GRAVITY: f32 : 36
SCALE :: 4
// sand constant
MAX_STEP_Y           :: 8

X_THRESHOLD          :: 1.0
MAX_VX               :: 2.5
MAX_VY               :: 8.0

X_FRICTION           :: 0.82
Y_DAMP_ON_HIT        :: 0.05

IMPACT_TO_SIDE       :: 0.20
NEIGHBOR_TRANSFER    :: 0.04
FALL_DRAG_TRANSFER   :: 0.02

SLEEP_EPSILON_X      :: 0.05
SLEEP_EPSILON_Y      :: 0.05
