/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "core:math/rand"
import "core:testing"

import "../models"

@(test)
test_components_are_packed_apart :: proc(t: ^testing.T) {
	// A pair, a line of three and a lone room: three components, the
	// biggest packed first, at the origin.
	area := area_of(
		room(100, {.East, 101}),
		room(101, {.West, 100}),
		room(110),
		room(120, {.South, 121}),
		room(121, {.North, 120}, {.South, 122}),
		room(122, {.North, 121}),
	)
	l := compute(&area)
	defer destroy(&l)
	expect_valid(t, &area, &l)
	testing.expect_value(t, len(l.components), 3)
	testing.expect_value(t, l.components[0].room_count, 2)
	testing.expect_value(t, l.components[1].room_count, 1)
	testing.expect_value(t, l.components[2].room_count, 3)
	testing.expect_value(t, l.components[2].min, Cell{0, 0, 0})
	testing.expect_value(t, l.min, Cell{0, 0, 0})
}

@(test)
test_layout_is_deterministic :: proc(t: ^testing.T) {
	area := random_area(t, 300)
	first := compute(&area)
	defer destroy(&first)
	second := compute(&area)
	defer destroy(&second)
	for r, i in first.rooms {
		testing.expect_value(t, second.rooms[i], r)
	}
	testing.expect_value(t, len(second.edges), len(first.edges))
}

@(test)
test_random_areas_are_valid :: proc(t: ^testing.T) {
	// Random exits make every kind of inconsistency at once.
	for size in ([]int{1, 2, 10, 100, 1000}) {
		area := random_area(t, size)
		l := compute(&area)
		expect_valid(t, &area, &l)
		destroy(&l)
	}
}

// `count` rooms (vnums 1..count) with random exits: mostly to other rooms,
// some look-only, some out of the area.
@(private = "file")
random_area :: proc(t: ^testing.T, count: int) -> models.Area {
	r := rand.create(t.seed)
	generator := rand.default_random_generator(&r)
	rooms := make([]models.Room, count, context.temp_allocator)
	for &room, i in rooms {
		room.vnum = i + 1
		for direction in models.Direction {
			roll := rand.int_max(10, generator)
			target: int
			switch {
			case roll < 5: continue
			case roll < 6: target = 0
			case roll < 7: target = 30000
			case: target = rand.int_max(count, generator) + 1
			}
			room.exits[direction] = models.Exit {
				direction = direction,
				target    = target,
			}
		}
	}
	return models.Area{rooms = rooms}
}
