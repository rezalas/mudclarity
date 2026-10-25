/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:strings"
import "core:testing"

import "../testkit"

// Shared helpers for the app tests.

// Paths in the temp allocator, as dialogs and drops deliver them.
paths :: proc(values: ..string) -> []string {
	out := make([]string, len(values), context.temp_allocator)
	copy(out, values)
	return out
}

// Run a load as the worker thread would, synchronously, and return its
// World_Loaded. The request's paths are copied to the heap as update does.
load_now :: proc(generation: int, values: ..string) -> World_Loaded {
	heap := runtime.heap_allocator()
	request := Load_Request {
		generation = generation,
		paths      = make([]string, len(values), heap),
	}
	for v, i in values {
		request.paths[i] = strings.clone(v, heap)
	}
	return load_world(request).(World_Loaded)
}

// Free a Load_Request's paths, which update allocates for the worker.
free_request :: proc(request: Load_Request) {
	heap := runtime.heap_allocator()
	for p in request.paths {
		delete(p, heap)
	}
	delete(request.paths, heap)
}

// Free everything a state owns, the way quitting does.
finish :: proc(s: State) {
	_, _ = step(s, Quit_Requested{})
}

// A temp dir holding the one-area BASE_ROOMS world. Returns the dir (remove
// it with os.remove_all) and its area.lst.
world_on_disk :: proc(t: ^testing.T, name: string) -> (dir, list: string) {
	dir = testkit.temp_dir(t, name)
	list = testkit.write_world(t, dir, testkit.area_text("A", testkit.BASE_ROOMS))
	return
}
