/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "core:math"

/*
 A force-directed layout for small graphs with no geometry of their own,
 such as the map of areas. Edges pull their nodes together, every pair of
 nodes pushes apart, and weak gravity keeps disconnected nodes from
 drifting off. Nodes start on a golden-angle spiral rather than at random,
 so a graph always gets the same picture. It is O(nodes²) per step, which
 is fine for the ~100 areas of a world.
*/

// An edge between nodes `a` and `b`. Heavier edges pull harder.
Graph_Edge :: struct {
	a, b:   int,
	weight: f32,
}

FORCE_STEPS :: 400
FORCE_EDGE_LENGTH :: f32(140) // Preferred distance between linked nodes
FORCE_GAP :: f32(24)          // Minimum space between node circles

// Positions for `radii` nodes (one radius each) joined by `edges`, centred
// on the origin, with no two circles overlapping. Allocated with
// `allocator`.
force_layout :: proc(radii: []f32, edges: []Graph_Edge, allocator := context.allocator) -> [][2]f32 {
	n := len(radii)
	pos := make([][2]f32, n, allocator)
	if n == 0 {
		return pos
	}
	golden := f32(math.PI * (3 - math.sqrt(f64(5))))
	for i in 0 ..< n {
		r := FORCE_EDGE_LENGTH * math.sqrt(f32(i) + 0.5)
		angle := f32(i) * golden
		pos[i] = {r * math.cos(angle), r * math.sin(angle)}
	}
	move := make([][2]f32, n, context.temp_allocator)
	k := FORCE_EDGE_LENGTH
	for step in 0 ..< FORCE_STEPS {
		temperature := k * (1 - f32(step) / FORCE_STEPS) + 1
		for &m in move {
			m = {}
		}
		for i in 0 ..< n {
			for j in i + 1 ..< n {
				d := pos[i] - pos[j]
				dist := max(length(d), 1)
				push := d / dist * (k * k / dist)
				move[i] += push
				move[j] -= push
			}
			move[i] -= pos[i] * 0.02 // Gravity towards the centre
		}
		for e in edges {
			if e.a == e.b || e.a < 0 || e.b < 0 || e.a >= n || e.b >= n {
				continue
			}
			d := pos[e.a] - pos[e.b]
			dist := max(length(d), 1)
			pull := d / dist * (dist * dist / k) * min(e.weight, 4)
			move[e.a] -= pull
			move[e.b] += pull
		}
		for i in 0 ..< n {
			if l := length(move[i]); l > 0 {
				pos[i] += move[i] / l * min(l, temperature)
			}
		}
	}
	separate(pos, radii)
	centre(pos)
	return pos
}

// Push overlapping circles apart until each pair keeps FORCE_GAP between
// them (a bounded number of passes; the force steps leave little to fix).
@(private = "file")
separate :: proc(pos: [][2]f32, radii: []f32) {
	for _ in 0 ..< 200 {
		moved := false
		for i in 0 ..< len(pos) {
			for j in i + 1 ..< len(pos) {
				need := radii[i] + radii[j] + FORCE_GAP
				d := pos[i] - pos[j]
				dist := length(d)
				if dist >= need {
					continue
				}
				dir := d / dist if dist > 0.001 else [2]f32{1, 0}
				shift := dir * (need - dist) / 2
				pos[i] += shift
				pos[j] -= shift
				moved = true
			}
		}
		if !moved {
			return
		}
	}
}

@(private = "file")
centre :: proc(pos: [][2]f32) {
	lo, hi := pos[0], pos[0]
	for p in pos {
		lo = {min(lo.x, p.x), min(lo.y, p.y)}
		hi = {max(hi.x, p.x), max(hi.y, p.y)}
	}
	mid := (lo + hi) / 2
	for &p in pos {
		p -= mid
	}
}

@(private = "file")
length :: proc(v: [2]f32) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}
