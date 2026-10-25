/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "../models"

// A neighbour reached by an exit in either direction: `direction` is the
// way to go from the current room to reach it.
@(private)
Link :: struct {
	room:      int,
	direction: models.Direction,
}

// Place every room, one component at a time, each in its own coordinates
// starting at the origin; pack_components moves them apart afterwards.
//
// A component is placed as islands. The first grows from the component's
// first room. A room whose cell is already taken is not forced in next to
// it; it starts a new island, which is fitted as a whole at the free spot
// nearest to where the room wanted to be. One geometry conflict then bends
// one connection instead of shifting every room placed after it.
place_rooms :: proc(area: ^models.Area, layout: ^Layout) {
	links := build_links(area)
	is_placed := make([]bool, len(area.rooms), context.temp_allocator)
	taken := make(map[Cell]int, context.temp_allocator) // Cells used by the current component
	pending := make([dynamic]Pending, context.temp_allocator)
	island := island_make(len(area.rooms))
	components := make([dynamic]Component, layout.allocator)

	for start in 0 ..< len(area.rooms) {
		if is_placed[start] {
			continue
		}
		component := len(components)
		append(&components, Component{first_room = start})
		clear(&taken)
		clear(&pending)
		append(&pending, Pending{room = start})
		room_count := 0

		for next := 0; next < len(pending); next += 1 {
			p := pending[next]
			if is_placed[p.room] {
				continue // Reached by another path since it was deferred
			}
			grow_island(&island, links, p.room, is_placed)
			offset := p.wanted if next == 0 else fit_island(&island, &taken, p.wanted)
			for member in island.members {
				cell := island.cells[member] + offset
				layout.rooms[member] = Placed_Room {
					vnum      = area.rooms[member].vnum,
					cell      = cell,
					component = component,
				}
				taken[cell] = member
				is_placed[member] = true
			}
			layout.rooms[p.room].is_displaced = offset != p.wanted
			room_count += len(island.members)
			for d in island.deferred {
				append(&pending, Pending{room = d.room, wanted = step(layout.rooms[d.from].cell, d.direction)})
			}
		}
		components[component].room_count = room_count
	}
	layout.components = components[:]
}

// A room waiting for an island of its own, and the cell its exit wanted.
@(private = "file")
Pending :: struct {
	room:   int,
	wanted: Cell,
}

// For each room, the rooms its exits lead to and the rooms whose exits lead
// to it, in a fixed order: its own exits in direction order, then incoming
// exits in file order. Exits to vnum 0 (look-only), to the room itself or
// out of the area are left out.
@(private)
build_links :: proc(area: ^models.Area) -> [][dynamic]Link {
	index := vnum_index(area, context.temp_allocator)
	outgoing := make([][dynamic]Link, len(area.rooms), context.temp_allocator)
	incoming := make([][dynamic]Link, len(area.rooms), context.temp_allocator)
	for i in 0 ..< len(area.rooms) {
		outgoing[i] = make([dynamic]Link, context.temp_allocator)
		incoming[i] = make([dynamic]Link, context.temp_allocator)
	}
	for room, i in area.rooms {
		for maybe_exit, direction in room.exits {
			exit := maybe_exit.? or_continue
			target, ok := room_index(index, exit.target)
			if !ok || target == i {
				continue
			}
			append(&outgoing[i], Link{target, direction})
			append(&incoming[target], Link{i, OPPOSITE[direction]})
		}
	}
	for &links, i in outgoing {
		append(&links, ..incoming[i][:])
	}
	return outgoing
}

// Room index by vnum. With duplicate vnums (which validation reports; the
// game won't boot) the first room is used and the others are only reached
// through their own exits.
vnum_index :: proc(area: ^models.Area, allocator := context.allocator) -> map[int]int {
	index := make(map[int]int, len(area.rooms), allocator)
	for room, i in area.rooms {
		if !(room.vnum in index) {
			index[room.vnum] = i
		}
	}
	return index
}

// The room an exit target names, if it is in the area. Vnum 0 is a
// look-only exit and never a room.
room_index :: proc(index: map[int]int, target: int) -> (room: int, ok: bool) {
	if target == 0 {
		return 0, false
	}
	room, ok = index[target]
	return
}
