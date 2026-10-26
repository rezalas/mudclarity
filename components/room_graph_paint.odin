/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:fmt"

import "gui:skald"

import "../layout"
import "../models"

/*
 Painting the room graph. Only the current level is drawn, and anything
 outside the canvas is skipped, so large areas stay cheap: the per-frame
 work is one pass over the area's rooms and edges with no allocation beyond
 label text.

 - Rooms: a box, outlined by their worst open finding (red error, amber
   warning, muted info), thicker in the accent colour when selected. A
   displaced room (its geometry conflicted) has a small dot in the corner.
 - Exits: straight corridors between neighbours; curves where the rooms
   aren't where the exit says (bent); an arrowhead on one-way exits; a
   triangle on the room for up/down exits and exits to another level; a
   short stub ending in a ring for exits that leave the area.
*/

// Zoom levels below which labels are left out, to keep small text from
// turning into noise.
VNUM_LABEL_ZOOM :: f32(0.45)
NAME_LABEL_ZOOM :: f32(1.15)

BENT_ALPHA :: f32(0.55)

paint_room_graph :: proc(d: ^Room_Graph_Data, p: skald.Canvas_Painter) {
	c := d.colors
	skald.draw_rect(p.r, p.bounds, c.bg, 0)
	origin := [2]f32{p.bounds.x, p.bounds.y}
	for e in d.layout.edges {
		paint_edge(d, p, origin, e)
	}
	for ext in d.layout.externals {
		paint_external(d, p, origin, ext)
	}
	for placed, i in d.layout.rooms {
		if placed.cell.z == d.state.level {
			paint_room(d, p, origin, i)
		}
	}
}

@(private = "file")
paint_room :: proc(d: ^Room_Graph_Data, p: skald.Canvas_Painter, origin: [2]f32, room: int) {
	c := d.colors
	zoom := d.state.camera.zoom
	centre := to_screen(d.state.camera, origin, cell_center(d.layout.rooms[room].cell))
	half := ROOM_SIZE * zoom / 2
	box := skald.Rect{centre.x - half, centre.y - half, half * 2, half * 2}
	if !overlaps(box, p.bounds) {
		return
	}
	radius := 6 * zoom
	skald.draw_rect(p.r, box, c.surface, radius)

	outline, width := c.border, f32(1)
	if mark := d.marks[room]; mark.has_finding {
		switch mark.worst {
		case .Error: outline, width = c.danger, 2
		case .Warning: outline, width = c.warning, 2
		case .Info: outline, width = c.fg_muted, 1.5
		}
	}
	if room == d.selected {
		outline, width = c.primary, 3
	}
	skald.draw_rect_outline(p.r, box, width, outline, radius, true)
	if d.layout.rooms[room].is_displaced {
		skald.draw_circle(p.r, {box.x + box.w - 6 * zoom, box.y + 6 * zoom}, 2.5 * zoom, c.fg_muted, true)
	}
	paint_level_markers(d, p, box, room)

	if zoom >= VNUM_LABEL_ZOOM {
		size := 11 * min(zoom, 1.5) * d.text_scale
		label := fmt.tprintf("%d", d.area.rooms[room].vnum)
		w, _ := skald.measure_text(p.r, label, size)
		// Large text sizes would spill out of the box: shrink to fit.
		if room_width := box.w - 4 * zoom; w > room_width && w > 0 {
			size *= room_width / w
			w = room_width
		}
		// draw_text takes the baseline, and `size` is the cap height.
		skald.draw_text(p.r, label, centre.x - w / 2, centre.y + size / 2, c.fg, size)
	}
	if zoom >= NAME_LABEL_ZOOM {
		size := 10 * min(zoom, 1.5) * d.text_scale
		name := fit_label(p.r, display_text(d.area.rooms[room].name), size, CELL_SIZE * zoom - 4)
		w, _ := skald.measure_text(p.r, name, size)
		baseline := box.y + box.h + 2 * zoom + skald.text_ascent(p.r, size)
		skald.draw_text(p.r, name, centre.x - w / 2, baseline, c.fg_muted, size)
	}
}

// Triangles on a room with exits to another level: up (top right,
// pointing up) and down (bottom right, pointing down).
@(private = "file")
paint_level_markers :: proc(d: ^Room_Graph_Data, p: skald.Canvas_Painter, box: skald.Rect, room: int) {
	placed := d.layout.rooms[room]
	zoom := d.state.camera.zoom
	s := 5 * zoom
	x := box.x + box.w - 7 * zoom
	if placed.leads_up {
		y := box.y + 5 * zoom
		skald.draw_polygon(p.r, {{x - s, y + s}, {x + s, y + s}, {x, y}}, d.colors.primary, true)
	}
	if placed.leads_down {
		y := box.y + box.h - 5 * zoom
		skald.draw_polygon(p.r, {{x - s, y - s}, {x + s, y - s}, {x, y}}, d.colors.primary, true)
	}
}

@(private = "file")
paint_edge :: proc(d: ^Room_Graph_Data, p: skald.Canvas_Painter, origin: [2]f32, e: layout.Edge) {
	from, to := d.layout.rooms[e.from].cell, d.layout.rooms[e.to].cell
	level := d.state.level
	if from.z != level || to.z != level {
		return // Shown as level markers on the room that is on this level
	}
	camera := d.state.camera
	a := to_screen(camera, origin, cell_center(from))
	b := to_screen(camera, origin, cell_center(to))
	if !overlaps(span(a, b, CELL_SIZE * camera.zoom), p.bounds) {
		return
	}
	c := d.colors
	half := ROOM_SIZE * camera.zoom / 2
	width := max(1, 2 * camera.zoom)
	out := direction_vector(e.direction)

	if e.kind == .Straight {
		start, end := a + out * half, b - out * half
		skald.draw_line(p.r, start, end, width, c.fg_muted, true)
		if !e.is_two_way {
			paint_arrowhead(p, end, out, camera.zoom, c.fg_muted)
		}
		return
	}
	// Bent: leave in the exit's direction and arrive from the opposite side
	// of whichever way the target lies, so the curve reads as "not where it
	// should be".
	back := direction_vector(layout.OPPOSITE[e.direction]) if e.is_two_way else -out
	reach := CELL_SIZE * camera.zoom * 0.6
	start, end := a + out * half, b + back * half
	// Translucent, so a tangle of conflicts doesn't hide the corridors.
	bent := c.warning
	bent[3] *= BENT_ALPHA
	skald.draw_bezier(p.r, start, start + out * reach, end + back * reach, end, width, bent, true)
	if !e.is_two_way {
		paint_arrowhead(p, end, -back, camera.zoom, bent)
	}
}

@(private = "file")
paint_external :: proc(d: ^Room_Graph_Data, p: skald.Canvas_Painter, origin: [2]f32, ext: layout.External_Exit) {
	cell := d.layout.rooms[ext.from].cell
	if cell.z != d.state.level || ext.direction == .Up || ext.direction == .Down {
		return
	}
	camera := d.state.camera
	centre := to_screen(camera, origin, cell_center(cell))
	out := direction_vector(ext.direction)
	start := centre + out * ROOM_SIZE * camera.zoom / 2
	end := start + out * CELL_SIZE * camera.zoom * 0.3
	if !overlaps(span(start, end, 8), p.bounds) {
		return
	}
	width := max(1, 1.5 * camera.zoom)
	skald.draw_line(p.r, start, end, width, d.colors.primary, true)
	skald.draw_rect_outline(p.r, {end.x - 4 * camera.zoom, end.y - 4 * camera.zoom, 8 * camera.zoom, 8 * camera.zoom}, width, d.colors.primary, 4 * camera.zoom, true)
}

@(private = "file")
paint_arrowhead :: proc(p: skald.Canvas_Painter, tip, toward: [2]f32, zoom: f32, color: skald.Color) {
	size := 7 * zoom
	side := [2]f32{-toward.y, toward.x}
	back := tip - toward * size
	skald.draw_polygon(p.r, {tip, back + side * size * 0.5, back - side * size * 0.5}, color, true)
}

// Screen direction of an exit. North is up the screen.
@(private = "file")
direction_vector :: proc(direction: models.Direction) -> [2]f32 {
	step := layout.DIRECTION_STEPS[direction]
	return {f32(step.x), f32(step.y)}
}

// The rectangle spanning two points, grown by `pad` on every side.
@(private = "file")
span :: proc(a, b: [2]f32, pad: f32) -> skald.Rect {
	lo := [2]f32{min(a.x, b.x), min(a.y, b.y)} - pad
	hi := [2]f32{max(a.x, b.x), max(a.y, b.y)} + pad
	return {lo.x, lo.y, hi.x - lo.x, hi.y - lo.y}
}

@(private = "file")
overlaps :: proc(a, b: skald.Rect) -> bool {
	return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

// `text` cut to fit `max_width` at `size`, ending in "…" if cut.
@(private = "file")
fit_label :: proc(r: ^skald.Renderer, text: string, size, max_width: f32) -> string {
	if w, _ := skald.measure_text(r, text, size); w <= max_width {
		return text
	}
	cut := len(text)
	for cut > 0 {
		cut -= 1
		for cut > 0 && (text[cut] & 0xC0) == 0x80 {
			cut -= 1 // Stay on a UTF-8 boundary
		}
		candidate := fmt.tprintf("%s…", text[:cut])
		if w, _ := skald.measure_text(r, candidate, size); w <= max_width {
			return candidate
		}
	}
	return ""
}
