/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "core:math"
import "core:testing"

@(private = "file")
distance :: proc(a, b: [2]f32) -> f32 {
	d := a - b
	return math.sqrt(d.x * d.x + d.y * d.y)
}

@(test)
test_force_layout_small_cases :: proc(t: ^testing.T) {
	testing.expect_value(t, len(force_layout(nil, nil, context.temp_allocator)), 0)
	one := force_layout({10}, nil, context.temp_allocator)
	testing.expect_value(t, one[0], [2]f32{0, 0}) // Centred
}

@(test)
test_force_layout_separates_and_groups :: proc(t: ^testing.T) {
	// A chain 0-1-2-3 and a separate pair 4-5, plus a lone node 6.
	radii := []f32{10, 30, 10, 20, 15, 15, 8}
	edges := []Graph_Edge{{0, 1, 1}, {1, 2, 1}, {2, 3, 1}, {4, 5, 3}}
	pos := force_layout(radii, edges, context.temp_allocator)
	for i in 0 ..< len(pos) {
		testing.expectf(t, !math.is_nan(pos[i].x) && !math.is_nan(pos[i].y), "node %d is not a number", i)
		for j in i + 1 ..< len(pos) {
			testing.expectf(t, distance(pos[i], pos[j]) >= radii[i] + radii[j] + FORCE_GAP - 0.5, "nodes %d and %d overlap", i, j)
		}
	}
	// Linked nodes end up closer than the average pair.
	total, pairs := f32(0), 0
	for i in 0 ..< len(pos) {
		for j in i + 1 ..< len(pos) {
			total += distance(pos[i], pos[j])
			pairs += 1
		}
	}
	average := total / f32(pairs)
	for e in edges {
		testing.expectf(t, distance(pos[e.a], pos[e.b]) < average, "edge %d-%d is longer than the average distance", e.a, e.b)
	}
}

@(test)
test_force_layout_is_deterministic :: proc(t: ^testing.T) {
	radii := []f32{10, 12, 14, 16, 18}
	edges := []Graph_Edge{{0, 1, 1}, {1, 2, 2}, {3, 4, 1}, {0, 4, 1}, {2, 2, 1}, {-1, 9, 1}} // Self and bad edges ignored
	first := force_layout(radii, edges, context.temp_allocator)
	second := force_layout(radii, edges, context.temp_allocator)
	for p, i in first {
		testing.expect_value(t, second[i], p)
	}
}
