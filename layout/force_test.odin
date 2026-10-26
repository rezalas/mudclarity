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

@(test)
test_force_layout_keeps_unlinked_nodes_close :: proc(t: ^testing.T) {
	// A chain of 30, alone and then with 30 nodes that have no edges. Left
	// to the forces, loose nodes were pushed out ~10,000 units, so a fitted
	// picture was mostly empty space. Packed, they take about one row.
	radii := make([]f32, 60, context.temp_allocator)
	edges := make([]Graph_Edge, 29, context.temp_allocator)
	for &r in radii {
		r = 10
	}
	for &e, i in edges {
		e = {i, i + 1, 1}
	}
	chain := force_layout(radii[:30], edges, context.temp_allocator)
	pos := force_layout(radii, edges, context.temp_allocator)
	for p, i in pos {
		for j in i + 1 ..< len(pos) {
			testing.expectf(t, distance(p, pos[j]) >= radii[i] + radii[j] + FORCE_GAP - 0.5, "nodes %d and %d overlap", i, j)
		}
	}
	// The chain is only moved, not changed.
	for i in 1 ..< 30 {
		testing.expectf(t, distance(pos[i] - pos[0], chain[i] - chain[0]) < 0.01, "chain node %d moved within the chain", i)
	}
	chain_size, size := extent(chain, radii[:30]), extent(pos, radii)
	row := 2 * (2 * radii[0] + FORCE_GROUP_GAP)
	testing.expectf(t, size.x <= chain_size.x + row && size.y <= chain_size.y + row, "the picture is %v across; the chain alone is %v", size, chain_size)
}

@(private = "file")
extent :: proc(pos: [][2]f32, radii: []f32) -> [2]f32 {
	lo, hi := [2]f32{max(f32), max(f32)}, [2]f32{min(f32), min(f32)}
	for p, i in pos {
		lo = {min(lo.x, p.x - radii[i]), min(lo.y, p.y - radii[i])}
		hi = {max(hi.x, p.x + radii[i]), max(hi.y, p.y + radii[i])}
	}
	return hi - lo
}
