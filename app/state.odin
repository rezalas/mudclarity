/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:strings"

import "../clarity"
import "../validation"
import "../workspace"

Screen :: enum u8 {
	Welcome, // Nothing open: open or drop a world
	World,   // A world is open
}

/*
 The whole GUI state. Skald passes it by value, so it holds only plain
 values and pointers; strings are heap-owned and replaced with set_text.
*/
State :: struct {
	screen:       Screen,
	ws:           ^workspace.Workspace, // The open world, or nil
	summary:      Summary,              // Counts for `ws`, computed when it loaded
	generation:   int,                  // Bumped by every load; older results are dropped
	loading_path: string,               // What is loading, or ""
	error:        string,               // The last error to show, or ""
}

// Counts about a loaded world, computed once on the loading thread so the
// view doesn't recount every frame.
Summary :: struct {
	rooms:        int,
	severities:   [validation.Severity]int,
	state_counts: [clarity.State]int,
}

init :: proc() -> State {
	return {}
}

// Whether a load is in progress.
is_loading :: proc(s: State) -> bool {
	return s.loading_path != ""
}

// Replace a heap-owned string in the state with a copy of `value`.
@(private)
set_text :: proc(field: ^string, value: string) {
	delete(field^)
	field^ = ""
	if value != "" {
		field^ = strings.clone(value)
	}
}

// Close a workspace from the GUI thread. Workspaces are opened on a loading
// thread with the heap allocator, so they are closed with it too, whatever
// allocator (e.g. the debug tracking allocator) the GUI thread uses.
@(private)
close_workspace :: proc(ws: ^workspace.Workspace) {
	context.allocator = runtime.heap_allocator()
	workspace.close(ws)
}
