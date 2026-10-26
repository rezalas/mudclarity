/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "gui:skald"

// Shared helpers for the components tests.

// A renderer that only records triangles (no GPU), as Skald's own drawing
// tests use. Free it with free_headless.
headless :: proc() -> ^skald.Renderer {
	r := new(skald.Renderer)
	r.cur = new(skald.Window_Target)
	r.alpha_multiplier = 1
	r.batch.vertices = make(type_of(r.batch.vertices))
	r.batch.indices = make([dynamic]u32)
	return r
}

free_headless :: proc(r: ^skald.Renderer) {
	delete(r.batch.vertices)
	delete(r.batch.indices)
	free(r.cur)
	free(r)
}

// The bounds of everything drawn so far.
drawn_bounds :: proc(r: ^skald.Renderer) -> (lo, hi: [2]f32) {
	lo, hi = {max(f32), max(f32)}, {min(f32), min(f32)}
	for v in r.batch.vertices {
		lo = {min(lo.x, v.pos.x), min(lo.y, v.pos.y)}
		hi = {max(hi.x, v.pos.x), max(hi.y, v.pos.y)}
	}
	return
}
