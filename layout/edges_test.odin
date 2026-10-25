/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "core:testing"

@(test)
test_two_way_exits_are_one_edge :: proc(t: ^testing.T) {
	area := area_of(room(100, {.East, 101}), room(101, {.West, 100}))
	l := compute(&area)
	defer destroy(&l)
	testing.expect_value(t, len(l.edges), 1)
	e := l.edges[0]
	testing.expect(t, e.is_two_way)
	testing.expect_value(t, e.from, 0) // Recorded from the first room in the file
	testing.expect_value(t, e.direction, .East)
	testing.expect_value(t, e.kind, Edge_Kind.Straight)
}

@(test)
test_one_way_exit :: proc(t: ^testing.T) {
	area := area_of(room(100, {.East, 101}), room(101))
	l := compute(&area)
	defer destroy(&l)
	testing.expect_value(t, len(l.edges), 1)
	testing.expect(t, !l.edges[0].is_two_way)
}

@(test)
test_return_by_another_direction_is_two_edges :: proc(t: ^testing.T) {
	// 100 east to 101, but 101 comes back north: not a matching pair.
	area := area_of(room(100, {.East, 101}), room(101, {.North, 100}))
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	testing.expect_value(t, len(l.edges), 2)
	for e in l.edges {
		testing.expect(t, !e.is_two_way)
	}
}

@(test)
test_vertical_edges :: proc(t: ^testing.T) {
	area := area_of(room(100, {.Up, 101}), room(101, {.Down, 100}))
	l := compute(&area)
	defer destroy(&l)
	testing.expect_value(t, len(l.edges), 1)
	testing.expect_value(t, l.edges[0].kind, Edge_Kind.Vertical)
	testing.expect_value(t, l.min.z, 0)
	testing.expect_value(t, l.max.z, 1)
}

@(test)
test_skipped_and_external_exits :: proc(t: ^testing.T) {
	area := area_of(
		room(
			100,
			{.North, 0},    // Look-only: no edge, no external
			{.East, 100},   // Back into itself: ignored
			{.South, 5000}, // Another area (or missing)
			{.West, -1},    // Broken
		),
	)
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	testing.expect_value(t, len(l.edges), 0)
	testing.expect_value(t, len(l.externals), 2)
	testing.expect_value(t, l.externals[0], External_Exit{from = 0, direction = .South, target = 5000})
	testing.expect_value(t, l.externals[1], External_Exit{from = 0, direction = .West, target = -1})
}
