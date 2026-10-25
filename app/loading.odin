/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"


/*
 Loading a world on a worker thread (cmd_thread). The worker never touches
 Skald or the GUI state: it gets a copy of the request and returns one
 World_Loaded. Everything that crosses between threads (request paths, the
 workspace, error text) is allocated and freed with the heap allocator,
 never the GUI thread's, which is a tracking allocator in debug builds.

 The worker must not assert or panic, which would end the whole process;
 errors are returned as text.
*/

// Open the world named by `request`: load, validate and lay it out.
load_world :: proc(request: Load_Request) -> Msg {
	context.allocator = runtime.heap_allocator()
	defer free_paths(request.paths)
	world, error := world_open(request.paths)
	return World_Loaded{generation = request.generation, world = world, error = error}
}

@(private = "file")
free_paths :: proc(paths: []string) {
	for path in paths {
		delete(path)
	}
	delete(paths)
}
