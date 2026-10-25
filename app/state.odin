/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:strings"

import "../components"

Screen :: enum u8 {
	Welcome, // Nothing open: open or drop a world
	World,   // A world is open
}

/*
 The whole GUI state. Skald passes it by value, so it holds only plain
 values and pointers; strings are heap-owned and replaced with set_text.
*/
State :: struct {
	screen:        Screen,
	world:         ^World, // The open world, or nil
	area:          int,    // The area shown, as an index into world.ws.areas
	selected_room: int,    // Room index in that area, or -1
	graph:         components.Room_Graph_State,
	generation:    int,    // Bumped by every load; older results are dropped
	loading_path:  string, // What is loading, or ""
	error:         string, // The last error to show, or ""
}

init :: proc() -> State {
	return State{selected_room = -1, graph = components.room_graph_init()}
}

// Show area `area` of the open world afresh: nothing selected, fitted.
show_area :: proc(s: ^State, area: int) {
	s.area = area
	s.selected_room = -1
	s.graph = components.room_graph_init()
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
