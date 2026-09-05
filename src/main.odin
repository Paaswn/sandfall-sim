package main

import "app"
import "core:log"
main :: proc() {
    a :=  new( app.App )
    defer free(a)
    
    app.init_app(a)
    app.run(a)
	app.delete_app(a)
}
