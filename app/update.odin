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
		out.screen = .World
		out.center = .Rooms
		out.area_map = components.area_map_init()
		show_area(&out, first_area_with_rooms(out.world))
		return out, Redraw_Soon{}

	case Close_World:
		world_close(out.world)
		out.world = nil
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
		if click, is_click := v.msg.(components.Room_Clicked); is_click {
			out.selected_room = click.room
			return out, nil
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
		// Following an exit shows its room, so it leaves the area map.
		effect: Effect
		if out.world != nil && out.center != .Rooms {
			out.center = .Rooms
			effect = Redraw_Soon{}
		}
		follow_exit(&out, v.target)
		return out, effect

	case Dismiss_Error:
		set_text(&out.error, "")

	case Redraw:

	case Theme_Changed:
		return out, Follow_System_Theme{}

	case Quit_Requested:
		world_close(out.world)
		out.world = nil
		set_text(&out.error, "")
		set_text(&out.loading_path, "")
		set_text(&out.note_draft, "")
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

// Select the room with vnum `target`, switching area if it is in another
// one, and centre the graph on it. Unknown vnums are ignored.
follow_exit :: proc(s: ^State, target: int) {
	if s.world == nil {
		return
	}
	ref, ok := s.world.rooms_by_vnum[target]
	if !ok {
		return
	}
	if ref.area != s.area {
		show_area(s, ref.area)
	}
	s.selected_room = ref.room
	s.graph = components.room_graph_update(s.graph, components.Focus_Room{ref.room}, &s.world.layouts[s.area])
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
