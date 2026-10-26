/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:strings"

import "gui:skald"

import "../clarity"
import "../components"
import "../models"
import "../settings"
import "../workspace"

// The update Skald calls: step, then turn the effect into a Command.
update :: proc(s: State, m: Msg) -> (State, skald.Command(Msg)) {
	next, effect := step(s, m)
	return next, command_for(effect)
}

// Advance the state. The only side effects here are freeing memory the
// state stops using (strings, a replaced or stale world); everything else
// is returned as an Effect.
step :: proc(s: State, m: Msg) -> (State, Effect) {
	out := s
	switch v in m {
	case Open_Requested:
		if is_loading(out) {
			return out, nil
		}
		return out, Show_Open_Dialog{}

	case Dialog_Cancelled:

	case Open_Paths:
		// Every request counts, so a startup request is made only once
		// even when it is refused.
		out.generation += 1
		paths := world_paths(v.paths)
		if len(paths) == 0 {
			set_text(&out.error, "Open an area.lst, or one or more .are files.")
			return out, nil
		}
		set_text(&out.error, "")
		set_text(&out.loading_path, paths[0])
		return out, Load_Request{generation = out.generation, paths = clone_paths(paths)}

	case World_Loaded:
		defer delete(v.error, runtime.heap_allocator())
		if v.generation != out.generation {
			world_close(v.world) // Superseded by a newer load
			return out, nil
		}
		set_text(&out.loading_path, "")
		if v.error != "" {
			set_text(&out.error, v.error)
			return out, nil
		}
		world_close(out.world)
		out.world = v.world
		apply_filters(out.world, out.settings.filters)
		set_search(&out, "")
		out.screen = .World
		out.center = .Rooms
		out.area_map = components.area_map_init()
		show_area(&out, first_area_with_rooms(out.world))
		return out, Redraw_Soon{}

	case Close_World:
		world_close(out.world)
		out.world = nil
		set_search(&out, "")
		out.screen = .Welcome
		show_area(&out, 0)

	case Area_Picked:
		if out.world == nil {
			return out, nil
		}
		for label, i in out.world.labels {
			if label == v.label && i != out.area {
				show_area(&out, i)
			}
		}

	case Graph:
		if out.world == nil {
			return out, nil
		}
		#partial switch e in v.msg {
		case components.Room_Clicked:
			out.selected_room = e.room
			return out, nil
		case components.Room_Deselected:
			out.selected_room = -1
			return out, nil
		case components.Exit_Key:
			return out, follow_exit_key(&out, e.direction)
		case components.Pan_Ended:
			// A press on empty space that hardly moved was a click: click
			// away to deselect (#46). A real drag keeps the selection.
			if out.graph.is_panning && out.graph.pan_distance < components.CLICK_SLOP {
				out.selected_room = -1
			}
		}
		out.graph = components.room_graph_update(out.graph, v.msg, &out.world.layouts[out.area])

	case Center_Chosen:
		if out.world == nil || v.view == out.center {
			return out, nil
		}
		out.center = v.view
		// The canvas just shown may not have a size to fit to yet.
		return out, Redraw_Soon{}

	case Area_Map:
		if out.world == nil {
			return out, nil
		}
		#partial switch e in v.msg {
		case components.Area_Clicked:
			// Selecting an area is picking it: the ring and the picker
			// follow, and its rooms are ready behind the switch.
			if e.area >= 0 && e.area < len(out.world.ws.areas) && e.area != out.area {
				show_area(&out, e.area)
			}
			return out, nil
		case components.Area_Opened:
			if e.area >= 0 && e.area < len(out.world.ws.areas) && e.area != out.area {
				show_area(&out, e.area)
			}
			out.center = .Rooms
			return out, Redraw_Soon{}
		}
		m := out.world.area_map
		out.area_map = components.area_map_update(out.area_map, v.msg, m.positions, m.rooms)

	case Search_Changed:
		set_search(&out, v.text)

	case Search_Chosen:
		set_search(&out, "")
		return out, go_to_room(&out, v.room)

	case Filters_Shown:
		out.filters_open = v.is_open

	case Severity_Shown:
		f := out.settings.filters
		if v.is_shown {
			f.severities += {v.severity}
		} else {
			f.severities -= {v.severity}
		}
		return set_filters(&out, f)

	case State_Shown:
		f := out.settings.filters
		if v.is_shown {
			f.states += {v.state}
		} else {
			f.states -= {v.state}
		}
		return set_filters(&out, f)

	case Filters_Reset:
		return set_filters(&out, DEFAULT_FILTERS)

	case Note_Draft_Changed:
		set_text(&out.note_draft, v.text)

	case Note_Added:
		return add_area_note(&out)

	case Review_Saved:
		defer delete(v.error, runtime.heap_allocator())
		if v.error != "" {
			set_text(&out.error, v.error)
		}

	case Exit_Followed:
		if out.world == nil {
			return out, nil
		}
		if ref, ok := out.world.rooms_by_vnum[v.target]; ok {
			return out, go_to_room(&out, ref)
		}

	case Dismiss_Error:
		set_text(&out.error, "")

	case Dismiss_Warning:
		set_text(&out.warning, "")

	case Settings_Shown:
		out.settings_open = v.is_open
		if v.is_open {
			out.help_open = false // One dialog at a time
		}

	case Help_Shown:
		out.help_open = v.is_open
		if v.is_open {
			out.settings_open = false
		}

	case Theme_Chosen:
		next := out.settings
		next.theme = v.theme
		return change_settings(&out, next)

	case Palette_Chosen:
		next := out.settings
		next.palette = v.palette
		return change_settings(&out, next)

	case Text_Scale_Chosen:
		out.text_scale_draft = 0
		next := out.settings
		next.text_scale = settings.clamp_text_scale(v.percent)
		if next.text_scale != out.settings.text_scale {
			// The canvases change size with the text: fit them again.
			out.graph.needs_fit = true
			out.area_map.needs_fit = true
		}
		return change_settings(&out, next)

	case Text_Scale_Dragged:
		out.text_scale_draft = settings.clamp_text_scale(v.percent)
		// The view applies it once the mouse is up; make sure a frame
		// follows to see that (an arrow key has no release to wait for).
		return out, Redraw_Soon{}

	case Settings_Saved:
		defer delete(v.error, runtime.heap_allocator())
		if v.error != "" {
			set_text(&out.error, v.error)
		}

	case Redraw:

	case Theme_Changed:
		// Only when following the OS; a chosen theme stays.
		if out.settings.theme == .System {
			return out, Follow_System_Theme{out.settings}
		}

	case Quit_Requested:
		world_close(out.world)
		out.world = nil
		set_text(&out.error, "")
		set_text(&out.warning, "")
		set_text(&out.loading_path, "")
		set_text(&out.note_draft, "")
		set_search(&out, "")
		return out, Quit{}
	}
	return out, nil
}

// Add the draft as a note on the area shown, in the review document, and
// ask for the file to be saved. A blank draft adds nothing.
@(private = "file")
add_area_note :: proc(s: ^State) -> (State, Effect) {
	text := strings.trim_space(s.note_draft)
	if s.world == nil || text == "" {
		return s^, nil
	}
	ws := s.world.ws
	err := workspace.add_note(ws, ws.names[s.area], clarity.KIND_AREA, 0, text, workspace.today(context.temp_allocator))
	if err != nil {
		set_text(&s.error, workspace.error_message(err, context.temp_allocator))
		return s^, nil
	}
	set_text(&s.note_draft, "")
	return s^, Save_Review{ws}
}

// Use new settings: apply and save them, unless nothing changed.
@(private = "file")
change_settings :: proc(s: ^State, next: settings.Settings) -> (State, Effect) {
	if next == s.settings {
		return s^, nil
	}
	s.settings = next
	return s^, Apply_Settings{s.store, next}
}

// Change the filters (a setting, so they are saved) and re-mark the open
// world's rooms and areas.
@(private = "file")
set_filters :: proc(s: ^State, filters: Filters) -> (State, Effect) {
	if s.world != nil && filters != s.settings.filters {
		apply_filters(s.world, filters)
	}
	next := s.settings
	next.filters = filters
	return change_settings(s, next)
}

// Follow the selected room's exit in `direction`, into another area if it
// leads there. With no such exit (or a look-only one), Page Up and Page
// Down show the level above or below instead; other directions do nothing.
@(private = "file")
follow_exit_key :: proc(s: ^State, direction: models.Direction) -> Effect {
	area := s.world.ws.areas[s.area]
	if s.selected_room < 0 || s.selected_room >= len(area.rooms) {
		return nil
	}
	if exit, ok := area.rooms[s.selected_room].exits[direction].?; ok && exit.target != 0 {
		if ref, found := s.world.rooms_by_vnum[exit.target]; found {
			return go_to_room(s, ref)
		}
		return nil // A missing room: nowhere to go
	}
	if direction == .Up || direction == .Down {
		level := s.graph.level + (1 if direction == .Up else -1)
		s.graph = components.room_graph_update(s.graph, components.Level_Changed{level}, &s.world.layouts[s.area])
	}
	return nil
}

// Select a room on the room graph, switching area if it is in another
// one, and centre the graph on it. Coming from the area map needs a frame
// for the graph's canvas to learn its size.
go_to_room :: proc(s: ^State, ref: Room_Ref) -> Effect {
	if s.world == nil || ref.area < 0 || ref.area >= len(s.world.ws.areas) || ref.room < 0 || ref.room >= len(s.world.ws.areas[ref.area].rooms) {
		return nil
	}
	effect: Effect
	if s.center != .Rooms {
		s.center = .Rooms
		effect = Redraw_Soon{}
	}
	if ref.area != s.area {
		show_area(s, ref.area)
	}
	s.selected_room = ref.room
	s.graph = components.room_graph_update(s.graph, components.Focus_Room{ref.room}, &s.world.layouts[s.area])
	return effect
}

// What to open from a set of chosen or dropped paths: the first area.lst
// (a whole world), else every .are file, else nothing. Points into `paths`.
world_paths :: proc(paths: []string) -> []string {
	for path in paths {
		if workspace.is_area_list(path) {
			return paths_of(path)
		}
	}
	areas := make([dynamic]string, context.temp_allocator)
	for path in paths {
		if workspace.is_area_file(path) {
			append(&areas, path)
		}
	}
	return areas[:]
}

@(private = "file")
paths_of :: proc(path: string) -> []string {
	one := make([]string, 1, context.temp_allocator)
	one[0] = path
	return one
}

// Heap copies of `paths` for a loading thread, which frees them.
@(private = "file")
clone_paths :: proc(paths: []string) -> []string {
	heap := runtime.heap_allocator()
	cloned := make([]string, len(paths), heap)
	for path, i in paths {
		cloned[i] = strings.clone(path, heap)
	}
	return cloned
}
