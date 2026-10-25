/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "../models"

// A group of rooms placed relative to each other, in local coordinates
// with the anchor (its first member) at the origin. Reused between islands
// to avoid reallocating; everything is in the temp allocator.
@(private)
Island :: struct {
	members:   [dynamic]int, // Rooms in placement order; members[0] is the anchor
	cells:     []Cell,       // Local cell of each member, indexed by room
	in_island: []bool,       // Indexed by room
	local:     map[Cell]int, // Members by local cell
	deferred:  [dynamic]Deferred,
}

// A room an island couldn't take because its cell was already used. It is
// reached from member `from` by going `direction`.
@(private)
Deferred :: struct {
	room:      int,
	from:      int,
	direction: models.Direction,
}

@(private)
island_make :: proc(room_count: int) -> Island {
	return Island {
		members = make([dynamic]int, context.temp_allocator),
		cells = make([]Cell, room_count, context.temp_allocator),
		in_island = make([]bool, room_count, context.temp_allocator),
		local = make(map[Cell]int, context.temp_allocator),
		deferred = make([dynamic]Deferred, context.temp_allocator),
	}
}

// Grow an island from `anchor` by walking links breadth-first, through
// rooms that aren't placed yet. A room whose cell the island already uses
// is deferred instead of being squeezed in.
@(private)
grow_island :: proc(island: ^Island, links: [][dynamic]Link, anchor: int, is_placed: []bool) {
	for member in island.members {
		island.in_island[member] = false
	}
	clear(&island.members)
	clear(&island.local)
	clear(&island.deferred)

	add_member(island, anchor, {0, 0, 0})
	for next := 0; next < len(island.members); next += 1 {
		current := island.members[next]
		for link in links[current] {
			if is_placed[link.room] || island.in_island[link.room] {
				continue
			}
			wanted := step(island.cells[current], link.direction)
			if wanted in island.local {
				append(&island.deferred, Deferred{room = link.room, from = current, direction = link.direction})
				continue
			}
			add_member(island, link.room, wanted)
		}
	}
}

@(private = "file")
add_member :: proc(island: ^Island, room: int, cell: Cell) {
	append(&island.members, room)
	island.cells[room] = cell
	island.in_island[room] = true
	island.local[cell] = room
}

// Where to put the island's anchor so that none of its rooms lands on a
// taken cell: `wanted` if possible, else the nearest such spot on the same
// level (by Manhattan distance within the smallest square ring that has
// one, ties in scan order). The taken cells are finite, so a ring far
// enough out always fits and this ends.
@(private)
fit_island :: proc(island: ^Island, taken: ^map[Cell]int, wanted: Cell) -> Cell {
	for radius := 0; ; radius += 1 {
		best: Cell
		best_distance := max(int)
		for dy in -radius ..= radius {
			for dx in -radius ..= radius {
				if abs(dx) != radius && abs(dy) != radius {
					continue // Inside the ring
				}
				distance := abs(dx) + abs(dy)
				offset := wanted + Cell{dx, dy, 0}
				if distance < best_distance && fits(island, taken, offset) {
					best, best_distance = offset, distance
				}
			}
		}
		if best_distance != max(int) {
			return best
		}
	}
}

@(private = "file")
fits :: proc(island: ^Island, taken: ^map[Cell]int, offset: Cell) -> bool {
	for member in island.members {
		if island.cells[member] + offset in taken {
			return false
		}
	}
	return true
}
