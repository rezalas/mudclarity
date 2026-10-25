/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"

import "../validation"
import "../workspace"

/*
 Loading a world on a worker thread (cmd_thread). The worker never touches
 Skald or the GUI state: it gets a copy of the request and returns one
 World_Loaded. Everything that crosses between threads (request paths, the
 workspace, error text) is allocated and freed with the heap allocator,
 never the GUI thread's, which is a tracking allocator in debug builds.

 The worker must not assert or panic, which would end the whole process;
 errors are returned as text.
*/

// Open the world named by `request`, validate it and count its findings.
load_world :: proc(request: Load_Request) -> Msg {
	context.allocator = runtime.heap_allocator()
	defer free_paths(request.paths)

	ws, err := workspace.open(request.paths)
	if err != nil {
		return World_Loaded{generation = request.generation, error = workspace.error_message(err)}
	}
	return World_Loaded{generation = request.generation, ws = ws, summary = summarize(ws)}
}

// Counts for the world's summary.
summarize :: proc(ws: ^workspace.Workspace) -> Summary {
	s: Summary
	for area in ws.areas {
		s.rooms += len(area.rooms)
	}
	s.severities = validation.count_by_severity(ws.diagnostics)
	s.state_counts = workspace.merge(ws, context.temp_allocator).state_counts
	return s
}

@(private = "file")
free_paths :: proc(paths: []string) {
	for path in paths {
		delete(path)
	}
	delete(paths)
}
