/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:math"
import "core:testing"

import "../layout"

@(private = "file")
close_to :: proc(a, b: [2]f32) -> bool {
	return math.abs(a.x - b.x) < 0.01 && math.abs(a.y - b.y) < 0.01
}

@(test)
test_screen_and_graph_round_trip :: proc(t: ^testing.T) {
	camera := Camera{pan = {30, -12}, zoom = 0.5}
	origin := [2]f32{100, 50}
	graph := [2]f32{144, -72}
	screen := to_screen(camera, origin, graph)
	testing.expect_value(t, screen, [2]f32{100 + 30 + 72, 50 - 12 - 36})
	testing.expect(t, close_to(to_graph(camera, origin, screen), graph))
}

@(test)
test_cell_at :: proc(t: ^testing.T) {
	cell, ok := cell_at(cell_center({2, -3, 0}), 4)
	testing.expect(t, ok)
	testing.expect_value(t, cell, layout.Cell{2, -3, 4})
	// Just inside and just outside a box's edge.
	_, ok = cell_at(cell_center({0, 0, 0}) + {ROOM_SIZE / 2 - 1, 0}, 0)
	testing.expect(t, ok)
	_, ok = cell_at(cell_center({0, 0, 0}) + {ROOM_SIZE / 2 + 1, 0}, 0)
	testing.expect(t, !ok, "the gap between rooms is not a room")
	cell, ok = cell_at({-CELL_SIZE + 3, -3}, 0)
	testing.expect(t, ok)
	testing.expect_value(t, cell, layout.Cell{-1, 0, 0})
}

@(test)
test_zoom_keeps_point_under_cursor :: proc(t: ^testing.T) {
	camera := Camera{pan = {10, 20}, zoom = 1}
	at := [2]f32{200, 150}
	before := (at - camera.pan) / camera.zoom
	zoomed := zoom_at(camera, 2, at)
	testing.expect_value(t, zoomed.zoom, f32(2))
	testing.expect(t, close_to((at - zoomed.pan) / zoomed.zoom, before))
	// Limits.
	testing.expect_value(t, zoom_at(camera, 1000, at).zoom, MAX_ZOOM)
	testing.expect_value(t, zoom_at(camera, 0.0001, at).zoom, MIN_ZOOM)
}

@(test)
test_fit_centres_and_never_zooms_in :: proc(t: ^testing.T) {
	size := [2]f32{800, 600}
	// One room: zoom 1, centred.
	camera := fit({0, 0, 0}, {0, 0, 0}, size)
	testing.expect_value(t, camera.zoom, f32(1))
	testing.expect(t, close_to(to_screen(camera, {}, cell_center({0, 0, 0})), size / 2))

	// A wide area: zoomed out so it fits inside the margins.
	camera = fit({0, 0, 0}, {40, 2, 0}, size)
	testing.expect(t, camera.zoom < 1)
	left := to_screen(camera, {}, cell_center({0, 0, 0}) - ROOM_SIZE / 2)
	right := to_screen(camera, {}, cell_center({40, 0, 0}) + ROOM_SIZE / 2)
	testing.expect(t, left.x >= FIT_MARGIN - 0.01 && right.x <= size.x - FIT_MARGIN + 0.01)
}
