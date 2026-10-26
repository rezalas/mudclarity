/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "core:math"
import "core:slice"

/*
 A force-directed layout for small graphs with no geometry of their own,
 such as the map of areas. Edges pull their nodes together, every pair of
 nodes pushes apart, and weak gravity keeps a group together. Each
 connected group is laid out on its own and the groups are then packed
 side by side, since nothing pulls a node without edges back in: left to
 the forces, it is pushed far away. Nodes start on a golden-angle spiral
 rather than at random, so a graph always gets the same picture. It is
 O(nodes²) per step, which is fine for the ~100 areas of a world.
*/

// An edge between nodes `a` and `b`. Heavier edges pull harder.
Graph_Edge :: struct {
	a, b:   int,
	weight: f32,
}

FORCE_STEPS :: 400
FORCE_EDGE_LENGTH :: f32(140) // Preferred distance between linked nodes
FORCE_GAP :: f32(24)          // Minimum space between node circles
FORCE_GROUP_GAP :: f32(48)    // Space between packed groups

// Positions for `radii` nodes (one radius each) joined by `edges`, centred
// on the origin, with no two circles overlapping. Edges with a node out of
// range are ignored. Allocated with `allocator`.
force_layout :: proc(radii: []f32, edges: []Graph_Edge, allocator := context.allocator) -> [][2]f32 {
	n := len(radii)
	pos := make([][2]f32, n, allocator)
	if n == 0 {
		return pos
	}
	groups := connected_groups(n, edges)
	local := make([]int, n, context.temp_allocator) // Node -> index in its group
	for members in groups {
		for node, k in members {
			local[node] = k
		}
	}
	group_of := make([]int, n, context.temp_allocator)
	group_radii := make([][dynamic]f32, len(groups), context.temp_allocator)
	group_edges := make([][dynamic]Graph_Edge, len(groups), context.temp_allocator)
	for members, g in groups {
		group_radii[g] = make([dynamic]f32, context.temp_allocator)
		group_edges[g] = make([dynamic]Graph_Edge, context.temp_allocator)
		for node in members {
			group_of[node] = g
			append(&group_radii[g], radii[node])
		}
	}
	for e in edges {
		if is_valid_edge(e, n) {
			g := group_of[e.a]
			append(&group_edges[g], Graph_Edge{local[e.a], local[e.b], e.weight})
		}
	}
	for members, g in groups {
		settled := settle(group_radii[g][:], group_edges[g][:])
		for node, k in members {
			pos[node] = settled[k]
		}
	}
	pack_groups(pos, radii, groups)
	centre(pos)
	return pos
}

// One connected group's positions, centred on the origin. Every edge must
// be valid. Allocated with the temp allocator.
@(private = "file")
settle :: proc(radii: []f32, edges: []Graph_Edge) -> [][2]f32 {
	n := len(radii)
	pos := make([][2]f32, n, context.temp_allocator)
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

@(private = "file")
is_valid_edge :: proc(e: Graph_Edge, n: int) -> bool {
	return e.a != e.b && e.a >= 0 && e.b >= 0 && e.a < n && e.b < n
}

// The nodes of each connected group, in node order; groups are in order of
// their first node. Allocated with the temp allocator.
@(private = "file")
connected_groups :: proc(n: int, edges: []Graph_Edge) -> [][dynamic]int {
	parent := make([]int, n, context.temp_allocator)
	for &p, i in parent {
		p = i
	}
	find :: proc(parent: []int, node: int) -> int {
		node := node
		for parent[node] != node {
			parent[node] = parent[parent[node]]
			node = parent[node]
		}
		return node
	}
	for e in edges {
		if is_valid_edge(e, n) {
			a, b := find(parent, e.a), find(parent, e.b)
			parent[max(a, b)] = min(a, b) // The lowest node is a group's root
		}
	}
	groups := make([dynamic][dynamic]int, context.temp_allocator)
	index := make([]int, n, context.temp_allocator) // Root -> group
	for node in 0 ..< n {
		root := find(parent, node)
		if root == node {
			index[node] = len(groups)
			append(&groups, make([dynamic]int, context.temp_allocator))
		}
		append(&groups[index[root]], node)
	}
	return groups[:]
}

@(private = "file")
Pack_Box :: struct {
	group:  int,
	lo, hi: [2]f32,
}

// Move the groups (each centred on the origin) apart: largest first, left
// to right in rows about as wide as the whole picture is tall.
@(private = "file")
pack_groups :: proc(pos: [][2]f32, radii: []f32, groups: [][dynamic]int) {
	boxes := make([]Pack_Box, len(groups), context.temp_allocator)
	area, widest := f32(0), f32(0)
	for members, g in groups {
		b := Pack_Box{g, {max(f32), max(f32)}, {min(f32), min(f32)}}
		for node in members {
			r := radii[node]
			b.lo = {min(b.lo.x, pos[node].x - r), min(b.lo.y, pos[node].y - r)}
			b.hi = {max(b.hi.x, pos[node].x + r), max(b.hi.y, pos[node].y + r)}
		}
		boxes[g] = b
		size := b.hi - b.lo + FORCE_GROUP_GAP
		area += size.x * size.y
		widest = max(widest, b.hi.x - b.lo.x)
	}
	// Biggest first; ties keep node order, so the result is stable.
	slice.stable_sort_by(boxes, proc(a, b: Pack_Box) -> bool {
		return (a.hi.x - a.lo.x) * (a.hi.y - a.lo.y) > (b.hi.x - b.lo.x) * (b.hi.y - b.lo.y)
	})
	row_width := max(widest, math.sqrt(area))
	x, y, row_height := f32(0), f32(0), f32(0)
	for b in boxes {
		size := b.hi - b.lo
		if x > 0 && x + size.x > row_width {
			x, y, row_height = 0, y + row_height + FORCE_GROUP_GAP, 0
		}
		offset := [2]f32{x, y} - b.lo
		for node in groups[b.group] {
			pos[node] += offset
		}
		x += size.x + FORCE_GROUP_GAP
		row_height = max(row_height, size.y)
	}
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
