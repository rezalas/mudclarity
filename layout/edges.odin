/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "../models"

// Turn every exit into an edge or an external exit, once rooms are placed.
// Look-only exits (vnum 0) and exits back into the same room are skipped.
// Two exits that lead to each other in opposite directions become one
// two-way edge, recorded from the room that comes first in the file.
build_edges :: proc(area: ^models.Area, layout: ^Layout) {
	index := vnum_index(area, context.temp_allocator)
	edges := make([dynamic]Edge, layout.allocator)
	externals := make([dynamic]External_Exit, layout.allocator)

	for room, from in area.rooms {
		for maybe_exit, direction in room.exits {
			exit := maybe_exit.? or_continue
			if exit.target == 0 {
				continue
			}
			to, in_area := room_index(index, exit.target)
			if !in_area {
				append(&externals, External_Exit{from = from, direction = direction, target = exit.target})
				continue
			}
			if to == from {
				continue
			}
			is_two_way := leads_back(area, to, OPPOSITE[direction], room.vnum)
			if is_two_way && to < from {
				continue // Already recorded from `to`
			}
			append(&edges, Edge{from = from, to = to, direction = direction, kind = edge_kind(layout, from, to, direction), is_two_way = is_two_way})
		}
	}
	layout.edges = edges[:]
	layout.externals = externals[:]
}

// Whether room `room`'s exit in `direction` leads to `vnum`.
@(private = "file")
leads_back :: proc(area: ^models.Area, room: int, direction: models.Direction, vnum: int) -> bool {
	exit, ok := area.rooms[room].exits[direction].?
	return ok && exit.target == vnum
}

@(private = "file")
edge_kind :: proc(layout: ^Layout, from, to: int, direction: models.Direction) -> Edge_Kind {
	if layout.rooms[to].cell != step(layout.rooms[from].cell, direction) {
		return .Bent
	}
	return .Vertical if direction == .Up || direction == .Down else .Straight
}
