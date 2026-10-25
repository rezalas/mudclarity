/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "core:testing"

import "../models"

// Shared helpers for the layout tests. Areas are built in memory: layout
// only reads rooms and exits, so no parsing is needed.

// An exit for `room`: direction and target vnum.
Exit_Spec :: struct {
	direction: models.Direction,
	target:    int,
}

// A room with the given exits. A second exit in the same direction replaces
// the first, as in the game.
room :: proc(vnum: int, exits: ..Exit_Spec) -> models.Room {
	r := models.Room {
		vnum = vnum,
	}
	for e in exits {
		r.exits[e.direction] = models.Exit {
			direction = e.direction,
			target    = e.target,
		}
	}
	return r
}

// An area holding copies of `rooms` (in the temp allocator).
area_of :: proc(rooms: ..models.Room) -> models.Area {
	copied := make([]models.Room, len(rooms), context.temp_allocator)
	copy(copied, rooms)
	return models.Area{rooms = copied}
}

// The cell of the room with `vnum` (its first room, for duplicates).
cell_of :: proc(t: ^testing.T, area: ^models.Area, l: ^Layout, vnum: int, loc := #caller_location) -> Cell {
	for r, i in area.rooms {
		if r.vnum == vnum {
			return l.rooms[i].cell
		}
	}
	testing.expectf(t, false, "no room #%d", vnum, loc = loc)
	return {}
}

// The edge between the rooms with these vnums, in either direction.
edge_between :: proc(t: ^testing.T, area: ^models.Area, l: ^Layout, a, b: int, loc := #caller_location) -> Edge {
	for e in l.edges {
		va, vb := area.rooms[e.from].vnum, area.rooms[e.to].vnum
		if (va == a && vb == b) || (va == b && vb == a) {
			return e
		}
	}
	testing.expectf(t, false, "no edge between #%d and #%d", a, b, loc = loc)
	return {}
}

// Check what every layout must satisfy: every room is placed exactly once,
// on its own cell, inside its component's bounds and the layout's; the
// components' bounds don't overlap; and each edge's kind matches where its
// rooms ended up.
expect_valid :: proc(t: ^testing.T, area: ^models.Area, l: ^Layout, loc := #caller_location) {
	testing.expect_value(t, len(l.rooms), len(area.rooms), loc = loc)
	testing.expect_value(t, len(l.cells), len(area.rooms), loc = loc)
	counted := 0
	for c in l.components {
		counted += c.room_count
	}
	testing.expect_value(t, counted, len(area.rooms), loc = loc)

	for r, i in l.rooms {
		at, ok := room_at(l, r.cell)
		testing.expectf(t, ok && at == i, "room %d's cell %v holds %d", i, r.cell, at, loc = loc)
		testing.expect_value(t, r.vnum, area.rooms[i].vnum, loc = loc)
		c := l.components[r.component]
		testing.expectf(t, inside(r.cell, c.min, c.max), "room %d at %v is outside its component %v..%v", i, r.cell, c.min, c.max, loc = loc)
		testing.expectf(t, inside(r.cell, l.min, l.max), "room %d at %v is outside the layout %v..%v", i, r.cell, l.min, l.max, loc = loc)
	}
	for a, i in l.components {
		for b in l.components[i + 1:] {
			apart := a.max.x < b.min.x || b.max.x < a.min.x || a.max.y < b.min.y || b.max.y < a.min.y
			testing.expectf(t, apart, "components overlap: %v..%v and %v..%v", a.min, a.max, b.min, b.max, loc = loc)
		}
	}
	for e in l.edges {
		testing.expect(t, e.from != e.to, loc = loc)
		is_step := l.rooms[e.to].cell == step(l.rooms[e.from].cell, e.direction)
		testing.expectf(t, is_step == (e.kind != .Bent), "edge %v has kind %v", e, e.kind, loc = loc)
	}
}

@(private = "file")
inside :: proc(cell, lo, hi: Cell) -> bool {
	return lo.x <= cell.x && cell.x <= hi.x && lo.y <= cell.y && cell.y <= hi.y && lo.z <= cell.z && cell.z <= hi.z
}
