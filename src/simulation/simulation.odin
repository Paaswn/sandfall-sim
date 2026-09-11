package simulation

Simulation :: struct {
	tick:      u32,
	world:     #soa []Cell2,
	chunks:    []Chunk,
	particles: [dynamic]Particle,
	config:    Simulation_Config,
	movement:  [dynamic][4]int,
}