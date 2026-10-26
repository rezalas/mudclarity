/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:testing"

import "gui:skald"

import "../validation"

@(test)
test_severity_markers_differ :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)
	drawn: [validation.Severity][dynamic][2]f32
	for severity in validation.Severity {
		r := headless()
		paint_severity_marker(r, {50, 50}, 10, severity, {1, 1, 1, 1})
		testing.expectf(t, len(r.batch.indices) > 0, "%v draws nothing", severity)
		lo, hi := drawn_bounds(r)
		// About `size` across, centred (antialiasing adds a fringe).
		testing.expectf(t, lo.x >= 43 && lo.y >= 43 && hi.x <= 57 && hi.y <= 57, "%v marker spans %v..%v", severity, lo, hi)
		drawn[severity] = make([dynamic][2]f32, context.temp_allocator)
		for v in r.batch.vertices {
			append(&drawn[severity], v.pos)
		}
		free_headless(r)
	}
	// Three different shapes (a cross, a triangle, a dot), not one shape
	// in three colours. Skald draws each as SDF quads, so compare where.
	same :: proc(a, b: [dynamic][2]f32) -> bool {
		if len(a) != len(b) do return false
		for p, i in a {
			if p != b[i] do return false
		}
		return true
	}
	testing.expect(t, !same(drawn[.Error], drawn[.Warning]))
	testing.expect(t, !same(drawn[.Warning], drawn[.Info]))
	testing.expect(t, !same(drawn[.Error], drawn[.Info]))
}

@(test)
test_markers_stay_in_their_place :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)
	// A room's: top left, above where the vnum label starts (40% down).
	box := skald.Rect{100, 100, ROOM_SIZE * 2, ROOM_SIZE * 2}
	r := headless()
	paint_room_marker(r, box, 2, .Error, {1, 1, 1, 1})
	lo, hi := drawn_bounds(r)
	testing.expectf(t, lo.x >= box.x && lo.y >= box.y && hi.x <= box.x + box.w / 2 && hi.y <= box.y + box.h * 0.4, "room marker at %v..%v", lo, hi)
	free_headless(r)

	// An area's: inside its circle.
	r = headless()
	paint_area_marker(r, {200, 200}, 30, .Warning, {1, 1, 1, 1})
	lo, hi = drawn_bounds(r)
	testing.expectf(t, lo.x >= 170 && lo.y >= 170 && hi.x <= 230 && hi.y <= 230, "area marker at %v..%v", lo, hi)
	free_headless(r)
}
