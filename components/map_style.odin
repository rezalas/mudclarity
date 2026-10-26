/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:math"

import "gui:skald"

/*
 How the maps draw what they mean, shared by the painters and the legend
 (legend.odin), so the legend always shows exactly what the maps draw:
 the colour and width of each outline and line, and the small shapes
 (arrowheads, level triangles, exit stubs, rings). Colours come from the
 theme, so the palette and light/dark follow.
*/

// Translucent, so a tangle of conflicting exits doesn't hide the corridors.
BENT_ALPHA :: f32(0.55)

// A room box's outline: the selection, else its worst finding shown, else
// a plain border.
room_outline :: proc(c: skald.Theme_Colors, mark: Room_Mark, is_selected: bool) -> (color: skald.Color, width: f32) {
	if is_selected {
		return c.primary, 3
	}
	if mark.has_finding {
		return severity_color(c, mark.worst), 1.5 if mark.worst == .Info else 2
	}
	return c.border, 1
}

// An area circle's outline: its worst finding shown, else a plain border.
area_outline :: proc(c: skald.Theme_Colors, mark: Room_Mark) -> (color: skald.Color, width: f32) {
	if !mark.has_finding {
		return c.border, 1.5
	}
	switch mark.worst {
	case .Error: width = 2.5
	case .Warning: width = 2
	case .Info: width = 1.5
	}
	return severity_color(c, mark.worst), width
}

// A straight exit (the way its direction says).
straight_exit_color :: proc(c: skald.Theme_Colors) -> skald.Color {
	return c.fg_muted
}

// A bent exit: one whose target isn't where its direction says.
bent_exit_color :: proc(c: skald.Theme_Colors) -> skald.Color {
	bent := c.warning
	bent[3] *= BENT_ALPHA
	return bent
}

// A link between areas: muted for exits, the accent when only portals
// join them.
link_color :: proc(c: skald.Theme_Colors, has_exits: bool) -> skald.Color {
	return c.fg_muted if has_exits else c.primary
}

// An unopened area's circle is drawn faint.
area_fill :: proc(c: skald.Theme_Colors, is_unopened: bool) -> skald.Color {
	fill := c.surface
	if is_unopened {
		fill[3] *= 0.45
	}
	return fill
}

// A filled arrowhead `size` long with its tip at `tip`, pointing along
// `toward` (a unit vector).
paint_arrowhead :: proc(r: ^skald.Renderer, tip, toward: [2]f32, size: f32, color: skald.Color) {
	side := [2]f32{-toward.y, toward.x}
	back := tip - toward * size
	skald.draw_polygon(r, {tip, back + side * size * 0.5, back - side * size * 0.5}, color, true)
}

// The triangle marking a room with an exit up (pointing up, its tip at
// `tip`) or down (pointing down); `s` is half its width.
paint_level_triangle :: proc(r: ^skald.Renderer, tip: [2]f32, s: f32, is_up: bool, color: skald.Color) {
	if is_up {
		skald.draw_polygon(r, {tip + {-s, s}, tip + {s, s}, tip}, color, true)
	} else {
		skald.draw_polygon(r, {tip + {-s, -s}, tip + {s, -s}, tip}, color, true)
	}
}

// An exit that leaves the area: a short line ending in a small square.
paint_exit_stub :: proc(r: ^skald.Renderer, start, end: [2]f32, zoom: f32, color: skald.Color) {
	width := max(1, 1.5 * zoom)
	skald.draw_line(r, start, end, width, color, true)
	skald.draw_rect_outline(r, {end.x - 4 * zoom, end.y - 4 * zoom, 8 * zoom, 8 * zoom}, width, color, 4 * zoom, true)
}

// A circle outline, as a closed polyline.
paint_ring :: proc(r: ^skald.Renderer, centre: [2]f32, radius, width: f32, color: skald.Color) {
	n := clamp(int(radius), 16, 96)
	points := make([][2]f32, n + 1, context.temp_allocator)
	for i in 0 ..= n {
		angle := 2 * math.PI * f32(i) / f32(n)
		points[i] = centre + {math.cos(angle), math.sin(angle)} * radius
	}
	skald.draw_polyline(r, points, width, color, true)
}

// A small filled circle. Skald's draw_circle uses one segment per 6 px of
// circumference, so under a ~3 px radius it comes out a triangle; a fully
// rounded rectangle is drawn as a signed distance field, round at any size.
paint_dot :: proc(r: ^skald.Renderer, at: [2]f32, radius: f32, color: skald.Color) {
	skald.draw_rect(r, {at.x - radius, at.y - radius, radius * 2, radius * 2}, color, radius)
}
