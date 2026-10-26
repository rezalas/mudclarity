/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:strings"

import "../components"
import "../settings"

Screen :: enum u8 {
	Welcome, // Nothing open: open or drop a world
	World,   // A world is open
}

// What the World screen shows beside the inspector.
Center_View :: enum u8 {
	Rooms, // The chosen area's room graph
	Areas, // The map of every area
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
	center:        Center_View,
	area_map:      components.Area_Map_State,
	note_draft:    string, // The note being written about the area shown
	search:        string, // The room search box
	search_hits:   []Room_Ref, // Its best matches (owned; see set_search)
	search_total:  int,        // How many rooms matched in all
	filters_open:  bool,       // The Filters popover is showing (the filters are in settings)
	generation:    int,    // Bumped by every load; older results are dropped
	loading_path:  string, // What is loading, or ""
	error:         string, // The last error to show, or ""
	warning:       string, // A warning to show (e.g. unreadable settings), or ""
	settings:      settings.Settings,  // The current settings (settings_store.odin)
	store:         ^Settings_Store,    // Where they are saved; nil saves nothing
	settings_open: bool,               // The Settings dialog is showing
	text_scale_draft: int,             // The text size slider while dragged (percent), or 0
}

init :: proc() -> State {
	return init_with(startup_store)
}

// The first state, with the settings `store` loaded (nil: the defaults,
// saved nowhere) and its warning, if any, showing.
init_with :: proc(store: ^Settings_Store) -> State {
	s := State {
		selected_room = -1,
		graph         = components.room_graph_init(),
		area_map      = components.area_map_init(),
		settings      = settings.DEFAULTS,
		store         = store,
	}
	if s.store != nil {
		s.settings = s.store.loaded.settings
		set_text(&s.warning, s.store.loaded.warning)
	}
	return s
}

// Show area `area` of the open world afresh: nothing selected, fitted.
show_area :: proc(s: ^State, area: int) {
	s.area = area
	s.selected_room = -1
	s.graph = components.room_graph_init()
	set_text(&s.note_draft, "") // A draft is about the area it was written for
}

// Set the room search query and its results. The results are owned by
// the state and replaced (or freed, with "") here.
set_search :: proc(s: ^State, query: string) {
	set_text(&s.search, query)
	delete(s.search_hits)
	s.search_hits, s.search_total = nil, 0
	if s.world != nil {
		s.search_hits, s.search_total = search_rooms(s.world.search_index, s.search, SEARCH_LIMIT)
	}
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
