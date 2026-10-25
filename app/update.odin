/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:strings"

import "gui:skald"

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
		return out, Quit{}
	}
	return out, nil
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
