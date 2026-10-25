/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "core:testing"

import "../models"

@(test)
test_single_room :: proc(t: ^testing.T) {
	area := area_of(room(100))
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	testing.expect_value(t, l.rooms[0].cell, Cell{0, 0, 0})
	testing.expect_value(t, len(l.components), 1)
	testing.expect_value(t, len(l.edges), 0)
}

@(test)
test_empty_area :: proc(t: ^testing.T) {
	area := area_of()
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	testing.expect_value(t, l.min, Cell{})
	testing.expect_value(t, l.max, Cell{})
}

@(test)
test_exits_follow_compass :: proc(t: ^testing.T) {
	// 101 north of 100, 102 east, 103 south, 104 west, 105 up, 106 down.
	area := area_of(
		room(100, {.North, 101}, {.East, 102}, {.South, 103}, {.West, 104}, {.Up, 105}, {.Down, 106}),
		room(101, {.South, 100}),
		room(102, {.West, 100}),
		room(103, {.North, 100}),
		room(104, {.East, 100}),
		room(105, {.Down, 100}),
		room(106, {.Up, 100}),
	)
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	origin := cell_of(t, &area, &l, 100)
	testing.expect_value(t, cell_of(t, &area, &l, 101) - origin, Cell{0, -1, 0})
	testing.expect_value(t, cell_of(t, &area, &l, 102) - origin, Cell{1, 0, 0})
	testing.expect_value(t, cell_of(t, &area, &l, 103) - origin, Cell{0, 1, 0})
	testing.expect_value(t, cell_of(t, &area, &l, 104) - origin, Cell{-1, 0, 0})
	testing.expect_value(t, cell_of(t, &area, &l, 105) - origin, Cell{0, 0, 1})
	testing.expect_value(t, cell_of(t, &area, &l, 106) - origin, Cell{0, 0, -1})
	for r in l.rooms {
		testing.expect(t, !r.is_displaced)
	}
}

@(test)
test_consistent_loop :: proc(t: ^testing.T) {
	// A square walked east, south, west, north: everything lines up.
	area := area_of(
		room(100, {.East, 101}, {.South, 103}),
		room(101, {.West, 100}, {.South, 102}),
		room(102, {.North, 101}, {.West, 103}),
		room(103, {.East, 102}, {.North, 100}),
	)
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	testing.expect_value(t, len(l.edges), 4)
	for e in l.edges {
		testing.expect_value(t, e.kind, Edge_Kind.Straight)
		testing.expect(t, e.is_two_way)
	}
}

@(test)
test_inconsistent_exit_is_bent :: proc(t: ^testing.T) {
	// 102 is south of 100, but 101 (east of 100) also claims 102 is south
	// of it. 100's exits come first, so 101 -> 102 is the bent one.
	area := area_of(room(100, {.East, 101}, {.South, 102}), room(101, {.South, 102}), room(102))
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	testing.expect_value(t, cell_of(t, &area, &l, 102) - cell_of(t, &area, &l, 100), Cell{0, 1, 0})
	testing.expect_value(t, edge_between(t, &area, &l, 101, 102).kind, Edge_Kind.Bent)
	testing.expect_value(t, edge_between(t, &area, &l, 100, 102).kind, Edge_Kind.Straight)
	testing.expect(t, !l.rooms[2].is_displaced, "102 got the cell it asked for")
}

@(test)
test_collision_moves_room :: proc(t: ^testing.T) {
	// 101's west exit leads to 102, not back to 100: 102 wants 100's cell.
	area := area_of(room(100, {.East, 101}), room(101, {.West, 102}), room(102))
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	moved := l.rooms[2]
	testing.expect(t, moved.is_displaced)
	// The nearest free cell to 100's: one step away, first in scan order.
	testing.expect_value(t, moved.cell - cell_of(t, &area, &l, 100), Cell{0, -1, 0})
	testing.expect_value(t, edge_between(t, &area, &l, 101, 102).kind, Edge_Kind.Bent)
}

@(test)
test_conflict_moves_its_neighbours_together :: proc(t: ^testing.T) {
	// 102 wants 100's cell, and 103 is south of 102. The pair moves as one
	// island, so only the conflicting exit (101 -> 102) bends.
	area := area_of(
		room(100, {.East, 101}),
		room(101, {.West, 102}),
		room(102, {.South, 103}),
		room(103, {.North, 102}),
	)
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	testing.expect(t, l.rooms[2].is_displaced, "102 moved off the cell it wanted")
	testing.expect(t, !l.rooms[3].is_displaced, "103 kept its place next to 102")
	testing.expect_value(t, cell_of(t, &area, &l, 103) - cell_of(t, &area, &l, 102), Cell{0, 1, 0})
	testing.expect_value(t, edge_between(t, &area, &l, 102, 103).kind, Edge_Kind.Straight)
	testing.expect_value(t, edge_between(t, &area, &l, 101, 102).kind, Edge_Kind.Bent)
	// Nearest spot where both fit: one step west of 100.
	testing.expect_value(t, cell_of(t, &area, &l, 102) - cell_of(t, &area, &l, 100), Cell{-1, 0, 0})
}

@(test)
test_crowded_collisions_spread_out :: proc(t: ^testing.T) {
	// Every room claims to be east of 100: one gets the cell, the rest
	// spread around it, each on a cell of its own.
	rooms := make([dynamic]models.Room, context.temp_allocator)
	append(&rooms, room(100))
	for vnum in 101 ..= 150 {
		append(&rooms, room(vnum, {.West, 100}))
	}
	area := area_of(..rooms[:])
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	displaced := 0
	for r in l.rooms {
		displaced += 1 if r.is_displaced else 0
	}
	testing.expect_value(t, displaced, 49)
	testing.expect_value(t, len(l.components), 1)
}

@(test)
test_incoming_exit_places_room :: proc(t: ^testing.T) {
	// Only 101 has an exit (north, to 100), so 100 has no way to 101 but
	// 101 still goes south of it, in the same component.
	area := area_of(room(100), room(101, {.North, 100}))
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	testing.expect_value(t, len(l.components), 1)
	testing.expect_value(t, cell_of(t, &area, &l, 101) - cell_of(t, &area, &l, 100), Cell{0, 1, 0})
}

@(test)
test_duplicate_vnums_get_their_own_cells :: proc(t: ^testing.T) {
	area := area_of(room(100, {.East, 101}), room(101, {.West, 100}), room(100))
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	testing.expect_value(t, len(l.components), 2)
}

@(test)
test_room_at_empty_cell :: proc(t: ^testing.T) {
	area := area_of(room(100))
	l := compute(&area)
	defer destroy(&l)
	_, ok := room_at(&l, {5, 5, 0})
	testing.expect(t, !ok)
}
