/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:testing"

// Two areas: a large one at the origin and a small one to its right.
@(private = "file")
two_areas :: proc() -> Area_Map_Data {
	positions := make([][2]f32, 2, context.temp_allocator)
	positions[0] = {0, 0}
	positions[1] = {200, 0}
	rooms := make([]int, 2, context.temp_allocator)
	rooms[0] = 100
	rooms[1] = 0
	return Area_Map_Data{state = area_map_init(), positions = positions, rooms = rooms}
}

@(test)
test_area_map_pan_zoom_and_fit :: proc(t: ^testing.T) {
	d := two_areas()
	s := d.state
	testing.expect(t, s.needs_fit)
	s = area_map_update(s, Pan_Started{}, d.positions, d.rooms)
	testing.expect(t, s.is_panning)
	s = area_map_update(s, Panned{{10, -4}}, d.positions, d.rooms)
	s = area_map_update(s, Panned{{1, 1}}, d.positions, d.rooms)
	testing.expect_value(t, s.camera.pan, [2]f32{11, -3})
	s = area_map_update(s, Pan_Ended{}, d.positions, d.rooms)
	testing.expect(t, !s.is_panning)
	s = area_map_update(s, Zoomed{factor = 2, at = {0, 0}}, d.positions, d.rooms)
	testing.expect_value(t, s.camera.zoom, f32(2))
	// Clicking an area is the host's business.
	testing.expect_value(t, area_map_update(s, Area_Clicked{1}, d.positions, d.rooms), s)

	size := [2]f32{800, 600}
	s = area_map_update(s, Fitted{size}, d.positions, d.rooms)
	testing.expect(t, !s.needs_fit)
	lo, hi := map_bounds(d.positions, d.rooms)
	a, b := to_screen(s.camera, {}, lo), to_screen(s.camera, {}, hi)
	testing.expectf(t, a.x >= 0 && a.y >= 0 && b.x <= size.x && b.y <= size.y, "fitted map %v..%v is outside %v", a, b, size)
}

@(test)
test_map_bounds_cover_nodes_and_labels :: proc(t: ^testing.T) {
	d := two_areas()
	lo, hi := map_bounds(d.positions, d.rooms)
	big, small := area_node_radius(100), area_node_radius(0)
	testing.expect_value(t, lo, [2]f32{-big, -big})
	testing.expect_value(t, hi, [2]f32{200 + small, big + 24})
	lo, hi = map_bounds(nil, nil)
	testing.expect_value(t, lo, hi)
}

@(test)
test_area_node_radius_grows_with_rooms :: proc(t: ^testing.T) {
	testing.expect_value(t, area_node_radius(0), f32(12))
	testing.expect_value(t, area_node_radius(-3), f32(12))
	testing.expect(t, area_node_radius(400) > area_node_radius(100))
}

@(test)
test_area_at_point :: proc(t: ^testing.T) {
	d := two_areas()
	area, ok := area_at_point(&d, {0, 0})
	testing.expect(t, ok)
	testing.expect_value(t, area, 0)
	area, ok = area_at_point(&d, {200 + area_node_radius(0) - 1, 0})
	testing.expect(t, ok)
	testing.expect_value(t, area, 1)
	_, ok = area_at_point(&d, {100, 0})
	testing.expect(t, !ok, "the space between areas is empty")

	// Points are canvas-local, so panning and zooming move the circles.
	d.state.camera = {pan = {50, 0}, zoom = 2}
	area, ok = area_at_point(&d, {50 + 400, 0})
	testing.expect(t, ok)
	testing.expect_value(t, area, 1)
	area, ok = area_at_point(&d, {50, 0})
	testing.expect(t, ok)
	testing.expect_value(t, area, 0)
	_, ok = area_at_point(&d, {50 + 200, 0})
	testing.expect(t, !ok)
}
