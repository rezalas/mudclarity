/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:testing"

import "../layout"
import "../models"

// Three rooms: 101 east of 100 (two-way) and 102 one level above 100.
@(private = "file")
three_rooms :: proc() -> models.Area {
	rooms := make([]models.Room, 3, context.temp_allocator)
	rooms[0] = {vnum = 100}
	rooms[0].exits[.East] = models.Exit{direction = .East, target = 101}
	rooms[0].exits[.Up] = models.Exit{direction = .Up, target = 102}
	rooms[1] = {vnum = 101}
	rooms[1].exits[.West] = models.Exit{direction = .West, target = 100}
	rooms[2] = {vnum = 102}
	rooms[2].exits[.Down] = models.Exit{direction = .Down, target = 100}
	return models.Area{rooms = rooms}
}

@(test)
test_graph_pan_and_zoom :: proc(t: ^testing.T) {
	area := three_rooms()
	l := layout.compute(&area)
	defer layout.destroy(&l)
	s := room_graph_init()
	s = room_graph_update(s, Pan_Started{}, &l)
	testing.expect(t, s.is_panning)
	s = room_graph_update(s, Panned{{10, -4}}, &l)
	s = room_graph_update(s, Panned{{1, 1}}, &l)
	testing.expect_value(t, s.camera.pan, [2]f32{11, -3})
	s = room_graph_update(s, Pan_Ended{}, &l)
	testing.expect(t, !s.is_panning)

	s = room_graph_update(s, Zoomed{factor = 2, at = {0, 0}}, &l)
	testing.expect_value(t, s.camera.zoom, f32(2))
	// Clicking a room is the host's business.
	testing.expect_value(t, room_graph_update(s, Room_Clicked{1}, &l), s)
}

@(test)
test_graph_levels_and_fit :: proc(t: ^testing.T) {
	area := three_rooms()
	l := layout.compute(&area)
	defer layout.destroy(&l)
	s := room_graph_init()
	testing.expect(t, s.needs_fit)
	s = room_graph_update(s, Fitted{{800, 600}}, &l)
	testing.expect(t, !s.needs_fit)

	s = room_graph_update(s, Level_Changed{1}, &l)
	testing.expect_value(t, s.level, 1)
	testing.expect(t, s.needs_fit, "a new level is fitted afresh")
	s = room_graph_update(s, Level_Changed{5}, &l)
	testing.expect_value(t, s.level, 1) // Clamped to the layout's levels
	s = room_graph_update(s, Level_Changed{-5}, &l)
	testing.expect_value(t, s.level, 0)

	lo, hi := level_bounds(&l, 0)
	testing.expect_value(t, lo, layout.Cell{0, 0, 0})
	testing.expect_value(t, hi, layout.Cell{1, 0, 0})
	lo, hi = level_bounds(&l, 1)
	testing.expect_value(t, lo, hi) // Just room 102
}

@(test)
test_room_at_point :: proc(t: ^testing.T) {
	area := three_rooms()
	l := layout.compute(&area)
	defer layout.destroy(&l)
	d := Room_Graph_Data {
		state  = room_graph_init(),
		area   = &area,
		layout = &l,
	}
	d.state.camera = Camera{pan = {100, 100}, zoom = 1}
	room, ok := room_at_point(&d, {100, 100}) // Room 100's centre
	testing.expect(t, ok)
	testing.expect_value(t, room, 0)
	room, ok = room_at_point(&d, {100 + CELL_SIZE, 100})
	testing.expect(t, ok && room == 1)
	_, ok = room_at_point(&d, {100 + CELL_SIZE / 2, 100})
	testing.expect(t, !ok, "between rooms")
	// Room 102 is above 100, so it is only hit on level 1.
	d.state.level = 1
	room, ok = room_at_point(&d, {100, 100})
	testing.expect(t, ok && room == 2)
}
